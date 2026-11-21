// SDK cache generation is deliberately an explicit operation, never a repository rule.
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

const schemaVersion = 3

// Request contains portable inputs. Paths to Xcode and the compiler live only in
// Toolchain, an ephemeral Bazel output populated from the resolved toolchain.
type Request struct {
	Targets         map[string]string   `json:"targets"`
	Defines         []string            `json:"defines"`
	ExcludeModules  map[string][]string `json:"exclude_modules"`
	FullSDKTracking bool                `json:"full_sdk_tracking"`
}

type Toolchain struct {
	Compiler     string   `json:"compiler"`
	Arguments    []string `json:"arguments"`
	DeveloperDir string   `json:"developer_dir"`
}

type Cache struct {
	SchemaVersion int                 `json:"schema_version"`
	Request       Request             `json:"request"`
	XcodeVersion  string              `json:"xcode_version"`
	SwiftVersion  string              `json:"swift_version"`
	Fingerprints  map[string]string   `json:"fingerprints"`
	Modules       map[string][]string `json:"modules"`
}

func readJSON(path string, value any) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	d := json.NewDecoder(f)
	d.DisallowUnknownFields()
	if err := d.Decode(value); err != nil {
		return fmt.Errorf("%s: %w", path, err)
	}
	var extra any
	if err := d.Decode(&extra); err != io.EOF {
		return fmt.Errorf("%s: unexpected trailing JSON", path)
	}
	return nil
}

// Atomic replacement leaves the previous committed cache intact on any failure.
func writeJSON(path string, value any) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(path), ".sdk-cache-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	if _, err = f.Write(append(data, '\n')); err != nil {
		f.Close()
		return err
	}
	if err = f.Chmod(0644); err != nil {
		f.Close()
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	return os.Rename(f.Name(), path)
}

func fingerprint(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func environment(developerDir string) []string {
	// Do not inherit include paths, alternate toolchains, or SDK overrides.
	blocked := map[string]bool{
		"CPATH": true, "CPLUS_INCLUDE_PATH": true, "C_INCLUDE_PATH": true,
		"OBJC_INCLUDE_PATH": true, "SDKROOT": true, "TOOLCHAINS": true,
		"SWIFT_MODULECACHE_PATH": true, "CLANG_MODULE_CACHE_PATH": true,
		"DEVELOPER_DIR": true,
	}
	var env []string
	for _, entry := range os.Environ() {
		key, _, _ := strings.Cut(entry, "=")
		if !blocked[key] {
			env = append(env, entry)
		}
	}
	return append(env, "DEVELOPER_DIR="+developerDir, "TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault")
}

func command(env []string, executable string, args ...string) ([]byte, error) {
	cmd := exec.Command(executable, args...)
	cmd.Env = env
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("%s failed: %w\n%s", filepath.Base(executable), err, stderr.String())
	}
	return out, nil
}

func (t Toolchain) run(args ...string) ([]byte, error) {
	return command(environment(t.DeveloperDir), t.Compiler, append(append([]string{}, t.Arguments...), args...)...)
}

func (t Toolchain) sdkPath(sdk string) (string, error) {
	out, err := command(environment(t.DeveloperDir), "/usr/bin/xcrun", "--sdk", strings.ToLower(sdk), "--show-sdk-path")
	if err != nil {
		return "", err
	}
	return filepath.EvalSymlinks(strings.TrimSpace(string(out)))
}

func (t Toolchain) stamp(request Request) (*Cache, error) {
	if !filepath.IsAbs(t.Compiler) || !filepath.IsAbs(t.DeveloperDir) {
		return nil, fmt.Errorf("cache generation requires an Xcode Swift toolchain selected by Bazel")
	}
	if len(request.Targets) == 0 {
		return nil, fmt.Errorf("configure at least one SDK target profile")
	}
	version, err := command(environment(t.DeveloperDir), "/usr/bin/xcrun", "xcodebuild", "-version")
	if err != nil {
		return nil, err
	}
	exact, err := xcodeVersion(string(version))
	if err != nil {
		return nil, err
	}
	swift, err := t.run("--version")
	if err != nil {
		return nil, err
	}
	c := &Cache{SchemaVersion: schemaVersion, Request: request, XcodeVersion: exact,
		SwiftVersion: strings.TrimSpace(string(swift)), Fingerprints: map[string]string{}, Modules: map[string][]string{}}
	inputs := map[string]string{
		"compiler/swiftc":     t.Compiler,
		"xcode/version.plist": filepath.Join(t.DeveloperDir, "..", "version.plist"),
	}
	for sdk, triple := range request.Targets {
		if err := validateProfile(sdk, triple); err != nil {
			return nil, err
		}
		path, err := t.sdkPath(sdk)
		if err != nil {
			return nil, err
		}
		inputs["sdk/"+sdk+"/SDKSettings.json"] = filepath.Join(path, "SDKSettings.json")
		if request.FullSDKTracking {
			if err := fingerprintTree("sdk/"+sdk, path, c.Fingerprints, map[string]bool{}); err != nil {
				return nil, err
			}
			frameworks, libraries := searchPaths(t.DeveloperDir, sdk, path)
			for i, root := range append(frameworks, libraries...) {
				if err := fingerprintTree(fmt.Sprintf("developer/%s/%d", sdk, i), root, c.Fingerprints, map[string]bool{}); err != nil {
					return nil, err
				}
			}
		}
	}
	if request.FullSDKTracking {
		if err := fingerprintTree("toolchain/lib", filepath.Join(filepath.Dir(t.Compiler), "..", "lib"), c.Fingerprints, map[string]bool{}); err != nil {
			return nil, err
		}
	}
	for name, path := range inputs {
		digest, err := fingerprint(path)
		if err != nil {
			return nil, err
		}
		c.Fingerprints[name] = digest
	}
	return c, nil
}

// Logical names, rather than installation paths or symlink destinations, enter
// the cache. Follow symlinks with ancestry-based cycle detection; aliases remain
// distinct logical inputs. A relocation of an unchanged Xcode has no effect.
func fingerprintTree(name, path string, out map[string]string, ancestors map[string]bool) error {
	real, err := filepath.EvalSymlinks(path)
	if err != nil {
		return err
	}
	info, err := os.Stat(real)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		digest, err := fingerprint(real)
		if err != nil {
			return err
		}
		out[name] = digest
		return nil
	}
	if ancestors[real] {
		return fmt.Errorf("cycle in SDK inputs at %s", name)
	}
	ancestors[real] = true
	defer delete(ancestors, real)
	out[name+"/"] = "directory"
	entries, err := os.ReadDir(real)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if err := fingerprintTree(name+"/"+entry.Name(), filepath.Join(real, entry.Name()), out, ancestors); err != nil {
			return err
		}
	}
	return nil
}

func xcodeVersion(output string) (string, error) {
	var version, build string
	for _, line := range strings.Split(output, "\n") {
		if strings.HasPrefix(line, "Xcode ") {
			version = strings.TrimPrefix(line, "Xcode ")
		}
		if strings.HasPrefix(line, "Build version ") {
			build = strings.TrimPrefix(line, "Build version ")
		}
	}
	if version == "" || build == "" {
		return "", fmt.Errorf("unrecognized Xcode version: %q", output)
	}
	parts := strings.Split(version, ".")
	for len(parts) < 3 {
		parts = append(parts, "0")
	}
	return strings.Join(parts, ".") + "." + build, nil
}

var sdks = map[string]struct{ os, suffix string }{
	"MacOSX": {"macosx", ""}, "iPhoneOS": {"ios", ""}, "iPhoneSimulator": {"ios", "-simulator"},
	"AppleTVOS": {"tvos", ""}, "AppleTVSimulator": {"tvos", "-simulator"},
	"WatchOS": {"watchos", ""}, "WatchSimulator": {"watchos", "-simulator"},
	"XROS": {"xros", ""}, "XRSimulator": {"xros", "-simulator"},
}

func validateProfile(sdk, triple string) error {
	info, ok := sdks[sdk]
	if !ok {
		return fmt.Errorf("unsupported SDK %q", sdk)
	}
	arch := "arm64"
	if sdk == "MacOSX" || info.suffix != "" {
		arch = "(arm64|x86_64)"
	}
	pattern := "^" + arch + "-apple-" + info.os + `[0-9]+(\.[0-9]+)*` + info.suffix + "$"
	if !regexp.MustCompile(pattern).MatchString(triple) {
		return fmt.Errorf("target %q does not match SDK %s", triple, sdk)
	}
	return nil
}

func sortedKeys[V any](values map[string]V) []string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}
