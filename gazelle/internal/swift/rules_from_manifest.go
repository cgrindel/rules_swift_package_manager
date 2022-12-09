package swift

import (
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

// func RulesFromManifest(args language.GenerateArgs, pi *swiftpkg.PackageInfo) []*rule.Rule {
// 	dump := pi.DumpManifest
// 	desc := pi.DescManifest
// 	shouldSetVis := shouldSetVisibility(args)

// 	var rules []*rule.Rule
// 	for _, dumpt := range dump.Targets {
// 		desct := desc.Targets.FindByName(dumpt.Name)
// 		srcs := desct.SourcesWithPath()

// 		var trules []*rule.Rule
// 		switch dumpt.Type {
// 		case spdump.LibraryTargetType:
// 			trules = rulesForLibraryModule(dumpt.Name, srcs, dumpt.Imports(), shouldSetVis)
// 		case spdump.ExecutableTargetType:
// 			trules = rulesForBinaryModule(dumpt.Name, srcs, dumpt.Imports(), shouldSetVis)
// 		case spdump.TestTargetType:
// 			trules = rulesForTestModule(dumpt.Name, srcs, dumpt.Imports(), shouldSetVis)
// 		}
// 		rules = append(rules, trules...)
// 	}

// 	return rules
// }

func RulesForSwiftProducts(args language.GenerateArgs, pi *swiftpkg.PackageInfo) []*rule.Rule {
	// TODO(chuck): IMPLEMENT ME!
	return nil
}

func RulesForSwiftTarget(args language.GenerateArgs, pi *swiftpkg.PackageInfo, targetName string) []*rule.Rule {
	dump := pi.DumpManifest
	desc := pi.DescManifest
	shouldSetVis := shouldSetVisibility(args)

	dumpt := dump.Targets.FindByName(targetName)
	desct := desc.Targets.FindByName(dumpt.Name)
	srcs := desct.Sources

	var rules []*rule.Rule
	switch dumpt.Type {
	case spdump.LibraryTargetType:
		rules = rulesForLibraryModule(dumpt.Name, srcs, dumpt.Imports(), shouldSetVis)
	case spdump.ExecutableTargetType:
		rules = rulesForBinaryModule(dumpt.Name, srcs, dumpt.Imports(), shouldSetVis)
	case spdump.TestTargetType:
		rules = rulesForTestModule(dumpt.Name, srcs, dumpt.Imports(), shouldSetVis)
	}

	return rules
}
