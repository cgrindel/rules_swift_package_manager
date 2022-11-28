package swift

import (
	"log"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

func RulesFromManifest(args language.GenerateArgs, pi *swiftpkg.PackageInfo) []*rule.Rule {
	dump := pi.DumpManifest
	desc := pi.DescManifest
	shouldSetVis := shouldSetVisibility(args)

	// DEBUG BEGIN
	log.Printf("*** CHUCK: RulesFromManifest desc: %+#v", desc)
	// DEBUG END

	var rules []*rule.Rule
	for _, dumpt := range dump.Targets {
		desct := desc.Targets.FindByName(dumpt.Name)
		srcs := desct.SourcesWithPath()

		var trules []*rule.Rule
		switch dumpt.Type {
		case spdump.LibraryTargetType:
			trules = rulesForLibraryModule(dumpt.Name, srcs, dumpt.Imports(), shouldSetVis)
		case spdump.ExecutableTargetType:
			trules = rulesForBinaryModule(dumpt.Name, srcs, dumpt.Imports(), shouldSetVis)
		case spdump.TestTargetType:
			trules = rulesForTestModule(dumpt.Name, srcs, dumpt.Imports(), shouldSetVis)
		}
		rules = append(rules, trules...)
	}

	return rules
}
