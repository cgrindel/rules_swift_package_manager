package gazelle

import (
	"log"
	"path/filepath"
	"sort"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/stringslices"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swiftcfg"
	"golang.org/x/exp/slices"
	"golang.org/x/text/cases"
	lang "golang.org/x/text/language"
)

func (l *swiftLang) GenerateRules(args language.GenerateArgs) language.GenerateResult {
	sc := swiftcfg.GetSwiftConfig(args.Config)
	switch sc.GenerateRulesMode(args) {
	case swiftcfg.SrcFileGenRulesMode:
		return genRulesFromSrcFiles(sc, args)
	default:
		return language.GenerateResult{}
	}
}

func genRulesFromSrcFiles(sc *swiftcfg.SwiftConfig, args language.GenerateArgs) language.GenerateResult {
	result := language.GenerateResult{}

	// Generate the rules from the protos (if any):
	rules := swift.RulesFromProtos(args, sc.SwiftGRPCFlavors)
	result.Gen = append(result.Gen, rules...)
	result.Imports = swift.Imports(result.Gen)

	// Collect Swift files
	swiftFiles := swift.FilterFiles(append(args.RegularFiles, args.GenFiles...))

	// Do not quick exit if we do not have any Swift source files in this directory. There may be
	// Swift source files in sub-directories.

	// Be sure to use args.Rel when determining whether this is a module directory. We do not want
	// to check directories that are outside of the workspace.
	moduleDir := swift.ModuleDir(sc.ConfigModulePaths(), args.Rel)
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
	if len(srcs) == 0 {
		return result
	}
	sort.Strings(srcs)

	// Generate the rules from sources:
	defaultName, defaultModuleName := defaultNameAndModuleName(args)
	rules = swift.RulesFromSrcs(args, srcs, defaultName, defaultModuleName, sc.SwiftLibraryTags)
	result.Gen = append(result.Gen, rules...)
	result.Imports = swift.Imports(result.Gen)
	result.Empty = generateEmpty(args, srcs)

	return result
}

func defaultNameAndModuleName(args language.GenerateArgs) (string, string) {

	// If the name is specified by a directive, short cirucit and return that:
	sc := swiftcfg.GetSwiftConfig(args.Config)
	if defaultModuleName, ok := sc.DefaultModuleNames[args.Rel]; ok {
		return defaultModuleName, defaultModuleName
	}

	// Otherwise, derive the name from the:
	// 1. Directory name.
	// 2. Repository name.
	// 3. "DefaultModule"
	var defaultName string
	if args.Rel == "" {
		defaultName = filepath.Base(args.Config.WorkDir)
	} else {
		defaultName = filepath.Base(args.Rel)
	}
	if ext := filepath.Ext(defaultName); ext != "" {
		defaultName = strings.TrimSuffix(defaultName, ext)
	}
	if defaultName == "." || defaultName == "" {
		defaultName = args.Config.RepoName
	}
	if defaultName == "" {
		defaultName = "DefaultModule"
	}

	// If configured to use PascalCase for module names, convert to that naming convention:
	defaultModuleName := defaultName
	if sc.ModuleNamingConvention == swiftcfg.PascalCaseModuleNamingConvention {
		moduleNameComponents := strings.Split(defaultModuleName, "_")
		caser := cases.Title(lang.English)
		pascalCaseModuleName := ""
		for _, component := range moduleNameComponents {
			pascalCaseModuleName += caser.String(component)
		}
		defaultModuleName = pascalCaseModuleName
	}

	return defaultName, defaultModuleName
}

// Look for any rules in the existing BUILD file that do not reference one of the source files. If
// we find any, then add an entry in empty rules list.
func generateEmpty(args language.GenerateArgs, srcs []string) []*rule.Rule {
	if args.File == nil {
		return nil
	}
	var empty []*rule.Rule
	for _, r := range args.File.Rules {
		if !swift.IsSwiftRuleKind(r.Kind()) {
			continue
		}
		isEmpty := true
		for _, src := range r.AttrStrings("srcs") {
			if _, ok := slices.BinarySearch(srcs, src); ok {
				isEmpty = false
				break
			}
		}
		if isEmpty {
			empty = append(empty, rule.NewRule(r.Kind(), r.Name()))
		}
	}
	return empty
}
