package gazelle

import (
	"log"
	"path/filepath"
	"sort"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/stringslices"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"golang.org/x/exp/slices"
)

func (l *swiftLang) GenerateRules(args language.GenerateArgs) language.GenerateResult {
	result := language.GenerateResult{}

	// Collect Swift files
	swiftFiles := swift.FilterFiles(append(args.RegularFiles, args.GenFiles...))
	if len(swiftFiles) == 0 {
		return result
	}

	// Be sure to use args.Rel when determining whether this is a module directory. We do not want
	// to check directories that are outside of the workspace.
	moduleDir := swift.ModuleDir(args.Rel)
	if args.Rel != moduleDir {
		relDir, err := filepath.Rel(moduleDir, args.Rel)
		if err != nil {
			log.Fatalf("failed to find the relative path for %s from %s. %s",
				args.Rel, moduleDir, err)
		}
		swiftFilesWithRelDir := stringslices.Map(swiftFiles, func(file string) string {
			return filepath.Join(relDir, file)
		})
		appendModuleFilesInSubdirs(moduleDir, swiftFilesWithRelDir)
		return result
	}

	// Retrieve any Swift files that have already been found
	srcs := append(swiftFiles, getModuleFilesInSubdirs(moduleDir)...)
	slices.Sort(srcs)

	fileInfos := createFileInfos(args.Dir, srcs)
	swiftImports, ruleKind := collectSwiftInfo(fileInfos)

	// Create a rule
	pkgName := filepath.Base(args.Rel)
	r := rule.NewRule(ruleKind, pkgName)
	r.SetAttr("srcs", srcs)
	r.SetPrivateAttr(config.GazelleImportsKey, swiftImports)
	setVisibility(args, r)
	result.Gen = append(result.Gen, r)

	result.Imports = make([]interface{}, len(result.Gen))
	for idx := range result.Gen {
		result.Imports[idx] = r.PrivateAttr(config.GazelleImportsKey)
	}

	return result
}

func setVisibility(args language.GenerateArgs, r *rule.Rule) {
	if !shouldSetVisibility(args) {
		return
	}

	var visibility []string
	switch r.Kind() {
	case swift.LibraryRuleKind, swift.BinaryRuleKind:
		visibility = []string{"//visibility:public"}
	}
	if len(visibility) > 0 {
		r.SetAttr("visibility", visibility)
	}
}

func shouldSetVisibility(args language.GenerateArgs) bool {
	// If the package has a default visibility set, do not set visibility
	if args.File != nil && args.File.HasDefaultVisibility() {
		return false
	}
	return true
}

func createFileInfos(dir string, srcs []string) []*swift.FileInfo {
	fileInfos := make([]*swift.FileInfo, len(srcs))
	for idx, src := range srcs {
		abs := filepath.Join(dir, src)
		fi, err := swift.NewFileInfoFromPath(src, abs)
		if err != nil {
			log.Printf("failed to create swift.FileInfo for %s. %s", abs, err)
			continue
		}
		fileInfos[idx] = fi
	}
	return fileInfos
}

func collectSwiftInfo(fileInfos []*swift.FileInfo) ([]string, string) {
	ruleKind := swift.LibraryRuleKind
	swiftImports := make([]string, 0)
	swiftImportsSet := make(map[string]bool)
	for _, fi := range fileInfos {
		// Collect the imports
		for _, imp := range fi.Imports {
			if _, ok := swiftImportsSet[imp]; !ok {
				swiftImportsSet[imp] = true
				swiftImports = append(swiftImports, imp)
			}
		}

		// Adjust the rule kind, if necessary
		switch {
		case fi.ContainsMain:
			ruleKind = swift.BinaryRuleKind
		case fi.IsTest:
			ruleKind = swift.TestRuleKind
		}
	}
	sort.Strings(swiftImports)
	return swiftImports, ruleKind
}

var moduleFilesInSubdirs = make(map[string][]string)

func appendModuleFilesInSubdirs(moduleDir string, paths []string) {
	var existingPaths []string
	if eps, ok := moduleFilesInSubdirs[moduleDir]; ok {
		existingPaths = eps
	}
	existingPaths = append(existingPaths, paths...)
	moduleFilesInSubdirs[moduleDir] = existingPaths
}

func getModuleFilesInSubdirs(moduleDir string) []string {
	var moduleSwiftFiles []string
	if eps, ok := moduleFilesInSubdirs[moduleDir]; ok {
		moduleSwiftFiles = eps
	}
	return moduleSwiftFiles
}
