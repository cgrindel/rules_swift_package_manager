package gazelle

import (
	"log"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/cgrindel/swift_bazel/gazelle/internal/stringslices"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
	"golang.org/x/exp/slices"
)

func (l *swiftLang) GenerateRules(args language.GenerateArgs) language.GenerateResult {
	sc := swiftcfg.GetSwiftConfig(args.Config)
	switch sc.GenerateRulesMode(args) {
	case swiftcfg.SwiftPkgGenRulesMode:
		return genRulesFromSwiftPkg(sc, args)
	case swiftcfg.SrcFileGenRulesMode:
		return genRulesFromSrcFiles(sc, args)
	default:
		return language.GenerateResult{}
	}
}

func genRulesFromSrcFiles(sc *swiftcfg.SwiftConfig, args language.GenerateArgs) language.GenerateResult {
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
		sc.ModuleFilesCollector.AppendModuleFiles(moduleDir, swiftFilesWithRelDir)
		return result
	}

	// Retrieve any Swift files that have already been found
	srcs := append(swiftFiles, sc.ModuleFilesCollector.GetModuleFiles(moduleDir)...)
	slices.Sort(srcs)

	// Generate the rules and imports
	result.Gen = swift.RulesFromSrcs(args, srcs)
	result.Imports = swift.Imports(result.Gen)

	return result
}

// Generate from Swift Package

func genRulesFromSwiftPkg(sc *swiftcfg.SwiftConfig, args language.GenerateArgs) language.GenerateResult {
	result := language.GenerateResult{}
	result.Gen = swift.RulesFromManifest(args, sc.PackageInfo)
	result.Imports = swift.Imports(result.Gen)
	return result
}
