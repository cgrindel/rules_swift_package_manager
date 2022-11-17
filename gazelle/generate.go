package gazelle

import (
	"log"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
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

	// fileInfos := createFileInfos(args.Dir, srcs)
	// swiftImports, ruleKind := collectSwiftInfo(fileInfos)

	// var rules []*rule.Rule
	// switch ruleKind {
	// case swift.LibraryRuleKind:
	// 	rules = rulesForSwiftLibrary()
	// case swift.BinaryRuleKind:
	// 	rules = rulesForSwiftBinary()
	// case swift.TestRuleKind:
	// 	rules = rulesForSwiftBinary()
	// }

	// // Create a rule
	// pkgName := filepath.Base(args.Rel)
	// r := rule.NewRule(ruleKind, pkgName)
	// r.SetAttr("srcs", srcs)
	// r.SetAttr(swift.ModuleNameAttrName, pkgName)
	// r.SetPrivateAttr(config.GazelleImportsKey, swiftImports)
	// setVisibility(args, r)
	// result.Gen = append(result.Gen, r)

	result.Gen = swift.Rules(args, srcs)

	result.Imports = make([]interface{}, len(result.Gen))
	for idx, r := range result.Gen {
		result.Imports[idx] = r.PrivateAttr(config.GazelleImportsKey)
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
