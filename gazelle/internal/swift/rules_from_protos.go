package swift

import (
	"strings"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/language/proto"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

// RulesFromProtos returns the Bazel build rule declarations for the provided source files.
func RulesFromProtos(args language.GenerateArgs, grpcFlavors []string) []*rule.Rule {

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
	var rules []*rule.Rule
	for protoPackageName, protoPackage := range protoPackages {
		rs := generateRuleFromProtoPackage(args, protoPackageName, protoPackage, grpcFlavors)
		rules = append(rules, rs...)
	}

	return rules
}

func generateRuleFromProtoPackage(
	args language.GenerateArgs,
	protoPackageName string,
	protoPackage proto.Package,
	grpcFlavors []string,
) []*rule.Rule {
	protoPrefix := strings.TrimSuffix(protoPackageName, "_proto")
	protoPackagePrefix := strings.ReplaceAll(args.Rel, "/", "_")
	shouldSetVis := shouldSetVisibility(args)

	// Generate the swift_proto_library:
	swiftProtoLibraryName := protoPrefix + swiftProtoSuffix
	swiftProtoLibraryModuleName := protoPackagePrefix + "_" + protoPackageName
	swiftProtoLibrary := rule.NewRule("swift_proto_library", swiftProtoLibraryName)
	swiftProtoLibrary.SetAttr("deps", []string{":" + protoPackageName})
	swiftProtoLibrary.SetPrivateAttr(config.GazelleImportsKey, []string{})
	swiftProtoLibrary.SetPrivateAttr(SwiftProtoModuleNameKey, swiftProtoLibraryModuleName)
	setVisibilityAttr(swiftProtoLibrary, shouldSetVis, []string{"//visibility:public"})
	rules := []*rule.Rule{swiftProtoLibrary}

	if protoPackage.HasServices {

		// Determine which flavors should be generated:
		var shouldGenerateClientFlavor bool
		var shouldGenerateClientStubsFlavor bool
		var shouldGenerateServerFlavor bool
		for _, flavor := range grpcFlavors {
			switch flavor {
			case "client":
				shouldGenerateClientFlavor = true
			case "client_stubs":
				shouldGenerateClientStubsFlavor = true
			case "server":
				shouldGenerateServerFlavor = true
			default:
				continue
			}
		}

		// Generate the client flavor:
		clientSwiftGRPCLibraryName := protoPrefix + "_client" + swiftGRPCSuffix
		if shouldGenerateClientFlavor {
			clientSwiftGRPCLibraryModuleName := protoPackagePrefix + "_" + clientSwiftGRPCLibraryName
			clientSwiftGRPCLibrary := rule.NewRule("swift_grpc_library", clientSwiftGRPCLibraryName)
			clientSwiftGRPCLibrary.SetAttr("srcs", []string{":" + protoPackageName})
			clientSwiftGRPCLibrary.SetAttr("deps", []string{":" + swiftProtoLibraryName})
			clientSwiftGRPCLibrary.SetAttr("flavor", "client")
			clientSwiftGRPCLibrary.SetPrivateAttr(config.GazelleImportsKey, []string{})
			clientSwiftGRPCLibrary.SetPrivateAttr(SwiftProtoModuleNameKey, clientSwiftGRPCLibraryModuleName)
			setVisibilityAttr(clientSwiftGRPCLibrary, shouldSetVis, []string{"//visibility:public"})
			rules = append(rules, clientSwiftGRPCLibrary)
		}

		// Generate the client_stubs flavor:
		if shouldGenerateClientStubsFlavor {
			clientStubsSwiftGRPCLibraryName := protoPrefix + "_client_stubs" + swiftGRPCSuffix
			clientStubsSwiftGRPCLibraryModuleName := protoPackagePrefix + "_" + clientStubsSwiftGRPCLibraryName
			clientStubsSwiftGRPCLibrary := rule.NewRule("swift_grpc_library", clientStubsSwiftGRPCLibraryName)
			clientStubsSwiftGRPCLibrary.SetAttr("srcs", []string{":" + protoPackageName})
			clientStubsSwiftGRPCLibrary.SetAttr("deps", []string{":" + clientSwiftGRPCLibraryName})
			clientStubsSwiftGRPCLibrary.SetAttr("flavor", "client_stubs")
			clientStubsSwiftGRPCLibrary.SetPrivateAttr(config.GazelleImportsKey, []string{})
			clientStubsSwiftGRPCLibrary.SetPrivateAttr(SwiftProtoModuleNameKey, clientStubsSwiftGRPCLibraryModuleName)
			setVisibilityAttr(clientStubsSwiftGRPCLibrary, shouldSetVis, []string{"//visibility:public"})
			rules = append(rules, clientStubsSwiftGRPCLibrary)
		}

		// Generate the server flavor:
		if shouldGenerateServerFlavor {
			serverSwiftGRPCLibraryName := protoPrefix + "_server" + swiftGRPCSuffix
			serverSwiftGRPCLibraryModuleName := protoPackagePrefix + "_" + serverSwiftGRPCLibraryName
			serverSwiftGRPCLibrary := rule.NewRule("swift_grpc_library", serverSwiftGRPCLibraryName)
			serverSwiftGRPCLibrary.SetAttr("srcs", []string{":" + protoPackageName})
			serverSwiftGRPCLibrary.SetAttr("deps", []string{":" + swiftProtoLibraryName})
			serverSwiftGRPCLibrary.SetAttr("flavor", "server")
			serverSwiftGRPCLibrary.SetPrivateAttr(config.GazelleImportsKey, []string{})
			serverSwiftGRPCLibrary.SetPrivateAttr(SwiftProtoModuleNameKey, serverSwiftGRPCLibraryModuleName)
			setVisibilityAttr(serverSwiftGRPCLibrary, shouldSetVis, []string{"//visibility:public"})
			rules = append(rules, serverSwiftGRPCLibrary)
		}
	}

	return rules
}
