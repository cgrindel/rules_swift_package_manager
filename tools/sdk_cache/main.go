package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"strings"
)

var moduleIdentifier = regexp.MustCompile(`^[A-Za-z_][A-Za-z_0-9]*$`)
var moduleDeclaration = regexp.MustCompile(`(?m)^\s*(?:extern\s+)?(?:framework\s+)?module\s+([A-Za-z_][A-Za-z_0-9]*)\b`)

func exists(path string) bool { _, err := os.Stat(path); return err == nil }

func searchPaths(developerDir, sdk, sdkPath string) (frameworks, libraries []string) {
	platform := filepath.Join(developerDir, "Platforms", sdk+".platform", "Developer")
	for _, path := range []string{filepath.Join(platform, "Library/Frameworks"), filepath.Join(sdkPath, "Developer/Library/Frameworks")} {
		if exists(path) {
			frameworks = append(frameworks, path)
		}
	}
	if path := filepath.Join(platform, "usr/lib"); exists(path) {
		libraries = append(libraries, path)
	}
	return
}

// Discover candidate top-level modules using the same SDK directory layout as
// rules_swift. The compiler's dependency graph, not these filenames, determines
// the final module names. Exclusions must match system_sdk.configure_sdks.
func candidates(directories []string, excluded []string) ([]string, error) {
	modules := map[string]bool{}
	for _, directory := range directories {
		entries, err := os.ReadDir(directory)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return nil, err
		}
		for _, entry := range entries {
			name := entry.Name()
			path := filepath.Join(directory, name)
			suffix := filepath.Ext(name)
			stem := strings.TrimSuffix(name, suffix)
			switch suffix {
			case ".swiftmodule", ".swiftcrossimport":
				modules[stem] = true
			case ".framework":
				if exists(filepath.Join(path, "Modules/module.modulemap")) || exists(filepath.Join(path, "Modules", stem+".swiftmodule")) {
					modules[stem] = true
				}
			case ".modulemap":
				if stem != "module" {
					modules[stem] = true
					continue
				}
				contents, err := os.ReadFile(path)
				if err != nil {
					return nil, err
				}
				for _, match := range moduleDeclaration.FindAllSubmatch(contents, -1) {
					modules[string(match[1])] = true
				}
			default:
				if exists(filepath.Join(path, "module.modulemap")) {
					modules[name] = true
				}
			}
		}
	}
	for _, name := range excluded {
		delete(modules, name)
	}
	for name := range modules {
		if !moduleIdentifier.MatchString(name) {
			return nil, fmt.Errorf("unsupported SDK module name %q", name)
		}
	}
	return sortedKeys(modules), nil
}

func (t Toolchain) inventory(cache *Cache) error {
	work, err := os.MkdirTemp("", "rspm-sdk-cache-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(work)
	for _, sdk := range sortedKeys(cache.Request.Targets) {
		path, err := t.sdkPath(sdk)
		if err != nil {
			return err
		}
		frameworks, libraries := searchPaths(t.DeveloperDir, sdk, path)
		directories := append(append([]string{}, frameworks...), libraries...)
		directories = append(directories, filepath.Join(path, "System/Library/Frameworks"), filepath.Join(path, "usr/lib/swift"), filepath.Join(path, "usr/include"))
		modules, err := candidates(directories, cache.Request.ExcludeModules[sdk])
		if err != nil {
			return err
		}
		if len(modules) == 0 {
			return fmt.Errorf("no module candidates in SDK %s", sdk)
		}
		source := filepath.Join(work, sdk+".swift")
		var text strings.Builder
		for _, name := range modules {
			fmt.Fprintf(&text, "import %s\n", name)
		}
		if err := os.WriteFile(source, []byte(text.String()), 0600); err != nil {
			return err
		}
		args := []string{"-frontend", "-scan-dependencies", "-module-name", "RSPMSDKInventory", "-sdk", path, "-target", cache.Request.Targets[sdk], "-module-cache-path", filepath.Join(work, "modules"), source}
		for _, path := range frameworks {
			args = append(args, "-F", path)
		}
		for _, path := range libraries {
			args = append(args, "-I", path)
		}
		fmt.Fprintf(os.Stderr, "Scanning SDK %s (%s)\n", sdk, cache.Request.Targets[sdk])
		output, err := t.run(args...)
		if err != nil {
			return fmt.Errorf("%s: %w", sdk, err)
		}
		names, err := graphModules(output)
		if err != nil {
			return err
		}
		for _, name := range names {
			cache.Modules[name] = append(cache.Modules[name], sdk)
		}
	}
	return nil
}

func graphModules(output []byte) ([]string, error) {
	var graph struct {
		Modules []map[string]json.RawMessage `json:"modules"`
	}
	if err := json.Unmarshal(output, &graph); err != nil {
		return nil, err
	}
	if len(graph.Modules) < 4 || len(graph.Modules)%2 != 0 {
		return nil, fmt.Errorf("unsupported compiler dependency graph")
	}
	names := map[string]bool{}
	for i := 2; i < len(graph.Modules); i += 2 {
		if len(graph.Modules[i]) != 1 {
			return nil, fmt.Errorf("unsupported module header in dependency graph")
		}
		for kind, value := range graph.Modules[i] {
			if kind != "swift" && kind != "clang" {
				return nil, fmt.Errorf("unsupported system module kind %q", kind)
			}
			var name string
			if err := json.Unmarshal(value, &name); err != nil {
				return nil, err
			}
			if !moduleIdentifier.MatchString(name) {
				return nil, fmt.Errorf("invalid module name %q", name)
			}
			names[name] = true
		}
	}
	return sortedKeys(names), nil
}

func run() error {
	capture := flag.String("capture-toolchain", "", "write an ephemeral toolchain descriptor (Bazel action only)")
	driver := flag.String("driver", "", "compiler executable from SwiftToolchainInfo")
	driverArgs := flag.String("driver-args", "[]", "JSON compiler prefix arguments")
	developer := flag.String("developer-dir", "", "Developer directory resolved by apple_support")
	toolchainPath := flag.String("toolchain", "", "Bazel-generated toolchain descriptor")
	requestPath := flag.String("request", "", "portable generation settings")
	outputPath := flag.String("output", "", "source-tree cache to write")
	validatePath := flag.String("validate", "", "validate this cache against the configured toolchain without rewriting it")
	flag.Parse()
	if flag.NArg() != 0 {
		return fmt.Errorf("unexpected positional arguments")
	}
	if *capture != "" {
		t := Toolchain{Compiler: *driver, DeveloperDir: *developer}
		if err := json.Unmarshal([]byte(*driverArgs), &t.Arguments); err != nil {
			return err
		}
		// Xcode toolchains expose a driver name, not a File. Resolve that name
		// only under the Developer directory selected by apple_support/Bazel.
		if t.Compiler == "swiftc" {
			if !filepath.IsAbs(t.DeveloperDir) {
				return fmt.Errorf("Bazel did not resolve an Xcode Developer directory")
			}
			out, err := command(environment(t.DeveloperDir), "/usr/bin/xcrun", "--find", "swiftc")
			if err != nil {
				return err
			}
			t.Compiler = strings.TrimSpace(string(out))
		}
		if !filepath.IsAbs(t.Compiler) {
			return fmt.Errorf("unsupported non-absolute Swift compiler %q", t.Compiler)
		}
		return writeJSON(*capture, t)
	}
	if *toolchainPath == "" || (*outputPath == "") == (*validatePath == "") {
		return fmt.Errorf("use a swift_sdk_cache target with either --output CACHE or --validate CACHE")
	}
	var t Toolchain
	if err := readJSON(*toolchainPath, &t); err != nil {
		return err
	}
	// bazel run starts in runfiles; user paths are relative to their workspace.
	if root := os.Getenv("BUILD_WORKSPACE_DIRECTORY"); root != "" {
		if err := os.Chdir(root); err != nil {
			return err
		}
	}
	if *validatePath != "" {
		var cached Cache
		if err := readJSON(*validatePath, &cached); err != nil {
			return err
		}
		if cached.SchemaVersion != schemaVersion {
			return fmt.Errorf("unsupported cache schema %d; regenerate", cached.SchemaVersion)
		}
		current, err := t.stamp(cached.Request)
		if err != nil {
			return err
		}
		if current.XcodeVersion != cached.XcodeVersion || current.SwiftVersion != cached.SwiftVersion || !reflect.DeepEqual(current.Fingerprints, cached.Fingerprints) {
			return fmt.Errorf("SDK cache is stale for the configured toolchain; rerun the generation target with --output %s", *validatePath)
		}
		return nil
	}
	if *requestPath == "" {
		return fmt.Errorf("--request is required for generation")
	}
	var request Request
	if err := readJSON(*requestPath, &request); err != nil {
		return err
	}
	cache, err := t.stamp(request)
	if err != nil {
		return err
	}
	if err := t.inventory(cache); err != nil {
		return err
	}
	return writeJSON(*outputPath, cache)
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "sdk_cache:", err)
		os.Exit(1)
	}
}
