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
	sc := getSwiftConfig(args.Config)
	switch sc.generateRulesMode(args) {
	case swiftPkgGenRulesMode:
		return genRulesFromSwiftPkg(sc, args)
	case srcFileGenRulesMode:
		return genRulesFromSrcFiles(sc, args)
	default:
		return language.GenerateResult{}
	}
}

func genRulesFromSrcFiles(sc *swiftConfig, args language.GenerateArgs) language.GenerateResult {
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
		sc.moduleFilesCollector.AppendModuleFiles(moduleDir, swiftFilesWithRelDir)
		return result
	}

	// Retrieve any Swift files that have already been found
	srcs := append(swiftFiles, sc.moduleFilesCollector.GetModuleFiles(moduleDir)...)
	slices.Sort(srcs)

	result.Gen = swift.Rules(args, srcs)
	result.Imports = make([]interface{}, len(result.Gen))
	for idx, r := range result.Gen {
		result.Imports[idx] = r.PrivateAttr(config.GazelleImportsKey)
	}

	return result
}

// Generate from Swift Package

func genRulesFromSwiftPkg(sc *swiftConfig, args language.GenerateArgs) language.GenerateResult {
	result := language.GenerateResult{}
	// TODO(chuck): IMPLEMENT ME!
	return result
}
