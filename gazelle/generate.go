package gazelle

import (
	"log"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
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
		dirRelToModuleRoot, err := filepath.Rel(moduleDir, args.Rel)
		if err != nil {
			log.Fatalf("failed to find the relative path for %s from %s. %s",
				args.Rel, moduleDir, err)
		}
		swiftFilesWithParentDir := make([]string, len(swiftFiles))
		for idx, swf := range swiftFiles {
			swiftFilesWithParentDir[idx] = filepath.Join(dirRelToModuleRoot, swf)
		}
		appendModuleFilesInSubdirs(moduleDir, swiftFilesWithParentDir)
		return result
	}

	// Retrieve any Swift files that have already been found
	srcs := append(swiftFiles, getModuleFilesInSubdirs(moduleDir)...)
	slices.Sort(srcs)

	// TODO(chuck): Add code to check for kind of rule

	// Create a rule
	pkgName := filepath.Base(args.Rel)
	r := rule.NewRule(swiftLibraryRule, pkgName)
	r.SetAttr("srcs", srcs)
	result.Gen = append(result.Gen, r)

	// TODO(chuck): What should I add for imports?
	result.Imports = make([]interface{}, len(result.Gen))
	for idx := range result.Gen {
		result.Imports[idx] = nil
	}

	return result
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
