package swift

import (
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

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
