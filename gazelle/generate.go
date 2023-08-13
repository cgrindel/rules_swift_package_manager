package gazelle

import (
	"log"
	"path/filepath"
	"sort"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/language/proto"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/stringslices"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swiftcfg"
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

	// Extract information about proto files.
	// We need this to exclude .pb.go files and generate swift_proto_library rules.
	// This is a collection of proto_library rule names that have a corresponding
	// swift_proto_library rule already generated.
	swiftProtoRules := make(map[string]struct{})
	protoPackages := make(map[string]proto.Package)
	for _, r := range args.OtherGen {
		if r.Kind() == "swift_proto_library" {
			if deps := r.AttrStrings("deps"); len(deps) > 0 {
				swiftProtoRules[deps[0]] = struct{}{}
			}
		}
		if r.Kind() != "proto_library" {
			continue
		}
		pkg := r.PrivateAttr(proto.PackageKey).(proto.Package)
		protoPackages[r.Name()] = pkg
	}

	// Generate the rules from proto packages:
	for protoPackageName, protoPackage := range protoPackages {
		rules := generateRuleFromProtoPackage(args, protoPackageName, protoPackage)
		result.Gen = append(result.Gen, rules...)
		result.Imports = swift.Imports(result.Gen)
	}

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

	// Generate the rules from sources:
	defaultModuleName := defaultModuleName(args)
	rules := swift.RulesFromSrcs(args, srcs, defaultModuleName)
	result.Gen = append(result.Gen, rules...)
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

func generateRuleFromProtoPackage(args language.GenerateArgs, protoPackageName string, protoPackage proto.Package) []*rule.Rule {
	protoPrefix := strings.TrimSuffix(protoPackageName, "_proto")
	protoPackagePrefix := strings.ReplaceAll(args.Rel, "/", "_")

	// Generate the swift_proto_library:
	swiftProtoLibraryName := protoPrefix + swiftProtoSuffix
	swiftProtoLibraryModuleName := protoPackagePrefix + "_" + protoPackageName
	swiftProtoLibrary := rule.NewRule("swift_proto_library", swiftProtoLibraryName)
	swiftProtoLibrary.SetAttr("deps", []string{":" + protoPackageName})
	swiftProtoLibrary.SetPrivateAttr(config.GazelleImportsKey, []string{})
	swiftProtoLibrary.SetPrivateAttr(swift.SwiftProtoModuleNameKey, swiftProtoLibraryModuleName)
	rules := []*rule.Rule{swiftProtoLibrary}

	if protoPackage.HasServices {
		// TODO: Github Issue #509 -- Add a configuration to selectively generate specific flavors.

		// Generate the client flavor:
		clientSwiftGRPCLibraryName := protoPrefix + "_client" + swiftGRPCSuffix
		clientSwiftGRPCLibraryModuleName := protoPackagePrefix + "_" + clientSwiftGRPCLibraryName
		clientSwiftGRPCLibrary := rule.NewRule("swift_grpc_library", clientSwiftGRPCLibraryName)
		clientSwiftGRPCLibrary.SetAttr("srcs", []string{":" + protoPackageName})
		clientSwiftGRPCLibrary.SetAttr("deps", []string{":" + swiftProtoLibraryName})
		clientSwiftGRPCLibrary.SetAttr("flavor", "client")
		clientSwiftGRPCLibrary.SetPrivateAttr(config.GazelleImportsKey, []string{})
		clientSwiftGRPCLibrary.SetPrivateAttr(swift.SwiftProtoModuleNameKey, clientSwiftGRPCLibraryModuleName)
		rules = append(rules, clientSwiftGRPCLibrary)

		// Generate the client_stubs flavor:
		clientStubsSwiftGRPCLibraryName := protoPrefix + "_client_stubs" + swiftGRPCSuffix
		clientStubsSwiftGRPCLibraryModuleName := protoPackagePrefix + "_" + clientStubsSwiftGRPCLibraryName
		clientStubsSwiftGRPCLibrary := rule.NewRule("swift_grpc_library", clientStubsSwiftGRPCLibraryName)
		clientStubsSwiftGRPCLibrary.SetAttr("srcs", []string{":" + protoPackageName})
		clientStubsSwiftGRPCLibrary.SetAttr("deps", []string{":" + clientSwiftGRPCLibraryName})
		clientStubsSwiftGRPCLibrary.SetAttr("flavor", "client_stubs")
		clientStubsSwiftGRPCLibrary.SetPrivateAttr(config.GazelleImportsKey, []string{})
		clientStubsSwiftGRPCLibrary.SetPrivateAttr(swift.SwiftProtoModuleNameKey, clientStubsSwiftGRPCLibraryModuleName)
		rules = append(rules, clientStubsSwiftGRPCLibrary)

		// Generate the server flavor:
		serverSwiftGRPCLibraryName := protoPrefix + "_server" + swiftGRPCSuffix
		serverSwiftGRPCLibraryModuleName := protoPackagePrefix + "_" + serverSwiftGRPCLibraryName
		serverSwiftGRPCLibrary := rule.NewRule("swift_grpc_library", serverSwiftGRPCLibraryName)
		serverSwiftGRPCLibrary.SetAttr("srcs", []string{":" + protoPackageName})
		serverSwiftGRPCLibrary.SetAttr("deps", []string{":" + swiftProtoLibraryName})
		serverSwiftGRPCLibrary.SetAttr("flavor", "server")
		serverSwiftGRPCLibrary.SetPrivateAttr(config.GazelleImportsKey, []string{})
		serverSwiftGRPCLibrary.SetPrivateAttr(swift.SwiftProtoModuleNameKey, serverSwiftGRPCLibraryModuleName)
		rules = append(rules, serverSwiftGRPCLibrary)
	}

	return rules
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
