package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

type graphPackage struct {
	Identity     string         `json:"identity"`
	Name         string         `json:"name"`
	Path         string         `json:"path"`
	Dependencies []graphPackage `json:"dependencies"`
}

type condition struct {
	Platforms     []string `json:"platformNames"`
	Configuration string   `json:"config"`
	Traits        []string `json:"traits"`
}

type setting struct {
	Tool      string                                `json:"tool"`
	Kind      map[string]map[string]json.RawMessage `json:"kind"`
	Condition *condition                            `json:"condition"`
}

type manifestTarget struct {
	Name              string                         `json:"name"`
	Type              string                         `json:"type"`
	Dependencies      []map[string][]json.RawMessage `json:"dependencies"`
	Settings          []setting                      `json:"settings"`
	PublicHeadersPath string                         `json:"publicHeadersPath"`
}

type manifest struct {
	Name     string           `json:"name"`
	Targets  []manifestTarget `json:"targets"`
	Products []struct {
		Name    string   `json:"name"`
		Targets []string `json:"targets"`
	} `json:"products"`
	ToolsVersion struct {
		Version string `json:"_version"`
	} `json:"toolsVersion"`
	LanguageVersions []string `json:"swiftLanguageVersions"`
	Traits           []struct {
		Name    string   `json:"name"`
		Enabled []string `json:"enabledTraits"`
	} `json:"traits"`
}

type describedTarget struct {
	Name       string   `json:"name"`
	C99name    string   `json:"c99name"`
	Path       string   `json:"path"`
	Sources    []string `json:"sources"`
	ModuleType string   `json:"module_type"`
}

type packageInfo struct {
	graph        graphPackage
	manifest     manifest
	targets      map[string]manifestTarget
	descriptions map[string]describedTarget
	traits       map[string]bool
	aliases      map[string]string
	aliasFlags   map[string]string
}

type scanRecord struct {
	SDK           string              `json:"sdk"`
	Configuration string              `json:"configuration"`
	Arguments     []string            `json:"arguments"`
	Imports       []string            `json:"imports"`
	Warnings      []map[string]string `json:"warnings"`
}

type targetCache struct {
	Inputs map[string]string `json:"inputs"`
	Scans  []scanRecord      `json:"scans"`
}

type packageCache struct {
	Inputs  map[string]string      `json:"inputs"`
	Targets map[string]targetCache `json:"targets"`
}

func (t Toolchain) swiftPackage(root string, args ...string) ([]byte, error) {
	// SwiftPM dispatch is selected by argv[0]; swiftc --driver-mode=swift
	// still treats "package" as an input file. Use the sibling Swift driver
	// in the configured toolchain, never a binary found on PATH.
	swift := filepath.Join(filepath.Dir(t.Compiler), "swift")
	return command(environment(t.DeveloperDir), swift, append([]string{"package", "--package-path", root}, args...)...)
}

func (t Toolchain) loadPackages(root string) (map[string]*packageInfo, error) {
	root, err := filepath.Abs(root)
	if err != nil {
		return nil, err
	}
	args := []string{}
	if exists(filepath.Join(root, "Package.resolved")) {
		args = append(args, "--force-resolved-versions")
	}
	args = append(args, "show-dependencies", "--format", "json")
	output, err := t.swiftPackage(root, args...)
	if err != nil {
		return nil, err
	}
	var graph graphPackage
	if err := json.Unmarshal(output, &graph); err != nil {
		return nil, err
	}
	packages := map[string]*packageInfo{}
	var visit func(graphPackage) error
	visit = func(g graphPackage) error {
		if g.Identity == "" || g.Path == "" {
			return fmt.Errorf("SwiftPM returned a package without identity/path")
		}
		if _, ok := packages[g.Identity]; ok {
			return nil
		}
		p := &packageInfo{graph: g, targets: map[string]manifestTarget{}, descriptions: map[string]describedTarget{}, traits: map[string]bool{}, aliases: map[string]string{}, aliasFlags: map[string]string{}}
		data, err := t.swiftPackage(g.Path, "dump-package")
		if err != nil {
			return err
		}
		if err := json.Unmarshal(data, &p.manifest); err != nil {
			return err
		}
		data, err = t.swiftPackage(g.Path, "describe", "--type", "json")
		if err != nil {
			return err
		}
		var description struct {
			Targets []describedTarget `json:"targets"`
		}
		if err := json.Unmarshal(data, &description); err != nil {
			return err
		}
		for _, target := range p.manifest.Targets {
			p.targets[target.Name] = target
		}
		for _, target := range description.Targets {
			p.descriptions[target.Name] = target
		}
		pending := []string{"default"}
		for len(pending) > 0 {
			name := pending[0]
			pending = pending[1:]
			if p.traits[name] {
				continue
			}
			p.traits[name] = true
			for _, trait := range p.manifest.Traits {
				if trait.Name == name {
					pending = append(pending, trait.Enabled...)
				}
			}
		}
		delete(p.traits, "default")
		packages[g.Identity] = p
		for _, child := range g.Dependencies {
			if err := visit(child); err != nil {
				return err
			}
		}
		return nil
	}
	if err := visit(graph); err != nil {
		return nil, err
	}
	// SwiftPM product aliases apply to the renamed package and its consumers.
	for _, p := range packages {
		for _, target := range p.targets {
			for _, dep := range target.Dependencies {
				values, ok := dep["product"]
				if !ok || len(values) < 3 {
					continue
				}
				var aliases map[string]string
				if err := json.Unmarshal(values[2], &aliases); err != nil {
					return nil, err
				}
				if len(aliases) == 0 {
					continue
				}
				child, _, err := reference(p, "product", values, packages)
				if err != nil {
					return nil, err
				}
				for original, renamed := range aliases {
					if old := child.aliases[original]; old != "" && old != renamed {
						return nil, fmt.Errorf("conflicting aliases for %s", original)
					}
					child.aliases[original] = renamed
				}
			}
		}
	}
	for _, p := range packages {
		for name, alias := range p.aliases {
			p.aliasFlags[name] = alias
		}
		for _, dep := range p.graph.Dependencies {
			for name, alias := range packages[dep.Identity].aliases {
				p.aliasFlags[name] = alias
			}
		}
	}
	return packages, nil
}

func active(c *condition, platform, config string, traits map[string]bool) bool {
	if c == nil {
		return true
	}
	if c.Configuration != "" && c.Configuration != config {
		return false
	}
	for _, trait := range c.Traits {
		if !traits[trait] {
			return false
		}
	}
	if len(c.Platforms) == 0 {
		return true
	}
	for _, value := range c.Platforms {
		if strings.ToLower(value) == platform || (value == "driverkit" && platform == "macos") {
			return true
		}
	}
	return false
}

func productRoots(p *packageInfo, name string) []string {
	for _, product := range p.manifest.Products {
		if product.Name == name {
			return product.Targets
		}
	}
	return nil
}

func reference(p *packageInfo, kind string, values []json.RawMessage, packages map[string]*packageInfo) (*packageInfo, []string, error) {
	if len(values) == 0 {
		return nil, nil, fmt.Errorf("empty %s dependency", kind)
	}
	var name, dependency string
	if err := json.Unmarshal(values[0], &name); err != nil {
		return nil, nil, err
	}
	if kind != "product" {
		if _, ok := p.targets[name]; ok {
			return p, []string{name}, nil
		}
		if roots := productRoots(p, name); len(roots) > 0 {
			return p, roots, nil
		}
	} else if len(values) > 1 {
		if err := json.Unmarshal(values[1], &dependency); err != nil {
			return nil, nil, err
		}
		if dependency == p.manifest.Name {
			return p, productRoots(p, name), nil
		}
	}
	var found *packageInfo
	var roots []string
	for _, dep := range p.graph.Dependencies {
		child := packages[dep.Identity]
		if dependency != "" && !strings.EqualFold(dependency, dep.Identity) && !strings.EqualFold(dependency, child.manifest.Name) {
			continue
		}
		if targets := productRoots(child, name); len(targets) > 0 {
			if found != nil {
				return nil, nil, fmt.Errorf("ambiguous product %s in %s", name, p.graph.Identity)
			}
			found, roots = child, targets
		}
	}
	if found == nil {
		return nil, nil, fmt.Errorf("cannot resolve dependency %s of %s", name, p.graph.Identity)
	}
	return found, roots, nil
}

func moduleName(p *packageInfo, name string) (string, error) {
	desc, ok := p.descriptions[name]
	if !ok || desc.C99name == "" {
		return "", fmt.Errorf("missing described target %s/%s", p.graph.Identity, name)
	}
	if desc.ModuleType == "ClangTarget" {
		headers := p.targets[name].PublicHeadersPath
		if headers == "" {
			headers = "include"
		}
		path := filepath.Join(p.graph.Path, desc.Path, headers, "module.modulemap")
		if exists(path) {
			data, err := os.ReadFile(path)
			if err != nil {
				return "", err
			}
			match := moduleDeclaration.FindSubmatch(data)
			if match == nil {
				return "", fmt.Errorf("unsupported custom module map %s", path)
			}
			return string(match[1]), nil
		}
	}
	return desc.C99name, nil
}

func dependencyModules(p *packageInfo, target, platform string, packages map[string]*packageInfo) ([]string, error) {
	visited, modules := map[string]bool{}, map[string]bool{}
	var walk func(*packageInfo, string) error
	walk = func(current *packageInfo, name string) error {
		key := current.graph.Identity + "/" + name
		if visited[key] {
			return nil
		}
		visited[key] = true
		module, err := moduleName(current, name)
		if err != nil {
			return err
		}
		modules[module] = true
		for _, dep := range current.targets[name].Dependencies {
			for kind, values := range dep {
				if kind != "byName" && kind != "target" && kind != "product" {
					return fmt.Errorf("unsupported dependency kind %s", kind)
				}
				index := 1
				if kind == "product" {
					index = 3
				}
				var c *condition
				if len(values) > index {
					if err := json.Unmarshal(values[index], &c); err != nil {
						return err
					}
				}
				if !active(c, platform, "", current.traits) {
					continue
				}
				child, roots, err := reference(current, kind, values, packages)
				if err != nil {
					return err
				}
				for _, root := range roots {
					if err := walk(child, root); err != nil {
						return err
					}
				}
			}
		}
		return nil
	}
	if err := walk(p, target); err != nil {
		return nil, err
	}
	return sortedKeys(modules), nil
}

func languageMode(m manifest) string {
	versions := append([]string{}, m.LanguageVersions...)
	if len(versions) == 0 {
		return strings.Split(m.ToolsVersion.Version, ".")[0]
	}
	sort.Slice(versions, func(i, j int) bool {
		left, right := strings.Split(versions[i], "."), strings.Split(versions[j], ".")
		for n := 0; n < max(len(left), len(right)); n++ {
			var l, r int
			if n < len(left) {
				l, _ = strconv.Atoi(left[n])
			}
			if n < len(right) {
				r, _ = strconv.Atoi(right[n])
			}
			if l != r {
				return l < r
			}
		}
		return false
	})
	return versions[len(versions)-1]
}

func settingValues(values map[string]json.RawMessage) ([]string, error) {
	var result []string
	for _, key := range sortedKeys(values) {
		var single string
		if err := json.Unmarshal(values[key], &single); err == nil {
			result = append(result, single)
			continue
		}
		var multiple []string
		if err := json.Unmarshal(values[key], &multiple); err != nil {
			return nil, fmt.Errorf("unsupported Swift build setting: %s", values[key])
		}
		result = append(result, multiple...)
	}
	return result, nil
}

func scanArguments(p *packageInfo, target manifestTarget, request Request, sdk, platform, config string, modules []string) ([]string, error) {
	desc := p.descriptions[target.Name]
	module := desc.C99name
	if alias := p.aliases[module]; alias != "" {
		module = alias
	}
	args := []string{"-frontend", "-scan-dependencies", "-import-prescan", "-module-name", module, "-sdk", "${SDK}", "-target", request.Targets[sdk], "-module-cache-path", "${MODULE_CACHE}", "-DSWIFT_PACKAGE"}
	if config == "release" {
		args = append(args, "-O")
	} else {
		args = append(args, "-Onone", "-DDEBUG")
	}
	for _, name := range append(append([]string{}, request.Defines...), sortedKeys(p.traits)...) {
		args = append(args, "-D"+name)
	}
	importable := map[string]bool{}
	for _, name := range modules {
		importable[name] = true
		if alias := p.aliasFlags[name]; alias != "" {
			importable[alias] = true
		}
	}
	for _, name := range sortedKeys(importable) {
		args = append(args, "-module-can-import", name)
	}
	for _, name := range sortedKeys(p.aliasFlags) {
		args = append(args, "-module-alias", name+"="+p.aliasFlags[name])
	}
	hasLanguage := false
	for _, s := range target.Settings {
		if s.Tool != "swift" {
			continue
		}
		if s.Condition != nil && !active(&condition{Traits: s.Condition.Traits}, "", "", p.traits) {
			continue
		}
		if active(s.Condition, platform, config, p.traits) {
			for kind := range s.Kind {
				switch kind {
				case "define", "unsafeFlags", "swiftLanguageMode", "enableExperimentalFeature", "enableUpcomingFeature":
				default:
					return nil, fmt.Errorf("unsupported Swift setting %s in %s/%s; retain manual SDK dependencies", kind, p.graph.Identity, target.Name)
				}
			}
		}
		if s.Kind["swiftLanguageMode"] != nil {
			hasLanguage = true
		}
	}
	if !hasLanguage {
		if mode := languageMode(p.manifest); mode != "" {
			args = append(args, "-swift-version", mode)
		}
	}
	for _, pair := range [][2]string{{"define", "-D"}, {"unsafeFlags", ""}, {"swiftLanguageMode", "-swift-version"}, {"enableExperimentalFeature", "-enable-experimental-feature"}, {"enableUpcomingFeature", "-enable-upcoming-feature"}} {
		for _, s := range target.Settings {
			values, ok := s.Kind[pair[0]]
			if !ok || s.Tool != "swift" || !active(s.Condition, platform, config, p.traits) {
				continue
			}
			parsed, err := settingValues(values)
			if err != nil {
				return nil, err
			}
			if pair[0] == "unsafeFlags" && len(parsed) > 0 {
				return nil, fmt.Errorf("SDK inference cannot reproduce unsafe Swift flags in %s/%s", p.graph.Identity, target.Name)
			}
			for _, value := range parsed {
				if pair[0] == "define" {
					args = append(args, "-D"+value)
				} else {
					args = append(args, pair[1], value)
				}
			}
		}
	}
	var sources []string
	for _, src := range desc.Sources {
		path := filepath.ToSlash(filepath.Join(desc.Path, src))
		if filepath.IsAbs(path) || strings.HasPrefix(path, "../") {
			return nil, fmt.Errorf("source is outside package: %s", path)
		}
		sources = append(sources, path)
	}
	sort.Strings(sources)
	return append(args, sources...), nil
}

func (t Toolchain) prescan(root, sdk, sdkPath, work string, arguments []string) ([]string, []map[string]string, error) {
	args := append([]string{}, t.Arguments...)
	for _, arg := range arguments {
		if arg == "${SDK}" {
			arg = sdkPath
		}
		if arg == "${MODULE_CACHE}" {
			arg = filepath.Join(work, "modules")
		}
		args = append(args, arg)
	}
	frameworks, libraries := searchPaths(t.DeveloperDir, sdk, sdkPath)
	for _, path := range frameworks {
		args = append(args, "-F", path)
	}
	for _, path := range libraries {
		args = append(args, "-I", path)
	}
	cmd := exec.Command(t.Compiler, args...)
	cmd.Dir, cmd.Env = root, environment(t.DeveloperDir)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	output, err := cmd.Output()
	if err != nil {
		return nil, nil, fmt.Errorf("Swift prescan failed: %w\n%s", err, stderr.String())
	}
	var result struct {
		Imports []string `json:"imports"`
	}
	if err := json.Unmarshal(output, &result); err != nil {
		return nil, nil, err
	}
	if result.Imports == nil {
		return nil, nil, fmt.Errorf("compiler did not return an imports array")
	}
	imports := map[string]bool{}
	for _, name := range result.Imports {
		imports[name] = true
	}
	warnings := []map[string]string{}
	for _, line := range strings.Split(stderr.String(), "\n") {
		if !strings.Contains(line, "cannot find user version number") {
			continue
		}
		_, name, ok := strings.Cut(line, "module '")
		if !ok {
			continue
		}
		name, _, _ = strings.Cut(name, "'")
		line = strings.NewReplacer(root, "${PACKAGE}", sdkPath, "${SDK}", t.DeveloperDir, "${DEVELOPER_DIR}", work, "${TEMP}").Replace(line)
		warnings = append(warnings, map[string]string{"module": name, "message": line})
	}
	return sortedKeys(imports), warnings, nil
}

func platformForSDK(sdk string) string {
	if sdk == "MacOSX" {
		return "macos"
	}
	if strings.HasPrefix(sdk, "XR") {
		return "visionos"
	}
	return sdks[sdk].os
}

func (t Toolchain) scanPackages(root string, cache *Cache) error {
	packages, err := t.loadPackages(root)
	if err != nil {
		return err
	}
	work, err := os.MkdirTemp("", "rspm-import-cache-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(work)
	cache.Packages = map[string]packageCache{}
	sdkPaths := map[string]string{}
	for sdk := range cache.Request.Targets {
		path, err := t.sdkPath(sdk)
		if err != nil {
			return err
		}
		sdkPaths[sdk] = path
	}
	for _, identity := range sortedKeys(packages) {
		p := packages[identity]
		pc := packageCache{Inputs: map[string]string{}, Targets: map[string]targetCache{}}
		manifests, err := filepath.Glob(filepath.Join(p.graph.Path, "Package*.swift"))
		if err != nil {
			return err
		}
		for _, path := range manifests {
			digest, err := fingerprint(path)
			if err != nil {
				return err
			}
			pc.Inputs[filepath.Base(path)] = digest
		}
		for _, name := range sortedKeys(p.targets) {
			target := p.targets[name]
			desc := p.descriptions[name]
			if target.Type == "test" || desc.ModuleType != "SwiftTarget" || len(desc.Sources) == 0 {
				continue
			}
			tc := targetCache{Inputs: map[string]string{}, Scans: []scanRecord{}}
			for _, src := range desc.Sources {
				path := filepath.ToSlash(filepath.Join(desc.Path, src))
				digest, err := fingerprint(filepath.Join(p.graph.Path, path))
				if err != nil {
					return err
				}
				tc.Inputs[path] = digest
			}
			memo := map[string]scanRecord{}
			for _, sdk := range sortedKeys(cache.Request.Targets) {
				modules, err := dependencyModules(p, name, platformForSDK(sdk), packages)
				if err != nil {
					return err
				}
				for _, config := range []string{"debug", "fastbuild", "release"} {
					args, err := scanArguments(p, target, cache.Request, sdk, platformForSDK(sdk), config, modules)
					if err != nil {
						return err
					}
					keyBytes, _ := json.Marshal(append([]string{sdk}, args...))
					key := string(keyBytes)
					record, ok := memo[key]
					if !ok {
						fmt.Fprintf(os.Stderr, "Scanning %s/%s (%s, %s)\n", identity, name, sdk, config)
						imports, warnings, err := t.prescan(p.graph.Path, sdk, sdkPaths[sdk], work, args)
						if err != nil {
							return err
						}
						record = scanRecord{SDK: sdk, Arguments: args, Imports: imports, Warnings: warnings}
						memo[key] = record
					}
					record.Configuration = config
					tc.Scans = append(tc.Scans, record)
				}
			}
			pc.Targets[name] = tc
		}
		cache.Packages["swiftpkg_"+strings.ReplaceAll(identity, "-", "_")] = pc
	}
	return nil
}
