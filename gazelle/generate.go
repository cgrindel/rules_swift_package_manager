package gazelle

import (
	"log"
	"path/filepath"
	"sort"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/stringslices"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
	"golang.org/x/exp/slices"
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

	// Collect Swift files
	swiftFiles := swift.FilterFiles(append(args.RegularFiles, args.GenFiles...))

	// Do not quick exit if we do not have any Swift source files in this directory. There may be
	// Swift source files in sub-directories.

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
	if len(srcs) == 0 {
		return result
	}
	sort.Strings(srcs)

	// Generate the rules and imports
	defaultModuleName := defaultModuleName(args)
	result.Gen = swift.RulesFromSrcs(args, srcs, defaultModuleName)
	result.Imports = swift.Imports(result.Gen)
	result.Empty = generateEmpty(args, srcs)

	return result
}

func defaultModuleName(args language.GenerateArgs) string {
	// Order of names to use
	// 1. Value specified via directive.
	// 2. Directory name.
	// 3. Repository name.
	// 4. "DefaultModule"

	// Check for a value configured via directive
	sc := swiftcfg.GetSwiftConfig(args.Config)
	var defaultModuleName string
	var ok bool
	if defaultModuleName, ok = sc.DefaultModuleNames[args.Rel]; ok {
		return defaultModuleName
	}
	if args.Rel == "" {
		defaultModuleName = filepath.Base(args.Config.WorkDir)
	} else {
		defaultModuleName = filepath.Base(args.Rel)
	}
	if ext := filepath.Ext(defaultModuleName); ext != "" {
		defaultModuleName = strings.TrimSuffix(defaultModuleName, ext)
	}
	if defaultModuleName == "." || defaultModuleName == "" {
		defaultModuleName = args.Config.RepoName
	}
	if defaultModuleName == "" {
		defaultModuleName = "DefaultModule"
	}
	return defaultModuleName
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
