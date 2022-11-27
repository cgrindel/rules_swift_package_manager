package swift

import (
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spdesc"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

func RulesFromManifest(args language.GenerateArgs, pi *swiftpkg.PackageInfo) []*rule.Rule {
	dump := pi.DumpManifest
	desc := pi.DescManifest
	shouldSetVis := shouldSetVisibility(args)

	var rules []*rule.Rule
	for _, dumpt := range dump.Targets {
		desct := desc.Targets.FindByName(dumpt.Name)
		var trules []*rule.Rule
		switch dumpt.Type {
		case spdump.LibraryTargetType:
			trules = rulesForLibraryTarget(&dumpt, desct, shouldSetVis)
		case spdump.ExecutableTargetType:
			trules = rulesForExecutableTarget(&dumpt, desct, shouldSetVis)
		case spdump.TestTargetType:
			trules = rulesForTestTarget(&dumpt, desct, shouldSetVis)
		}
		rules = append(rules, trules...)
	}

	return rules
}

func rulesForLibraryTarget(dumpt *spdump.Target, desct *spdesc.Target, shouldSetVis bool) []*rule.Rule {
	imports := make([]string, len(dumpt.Dependencies))
	for idx, td := range dumpt.Dependencies {
		imports[idx] = td.ImportName()
	}
	return rulesForLibraryModule(dumpt.Name, desct.Sources, imports, shouldSetVis)
}

func rulesForExecutableTarget(dumpt *spdump.Target, desct *spdesc.Target, shouldSetVis bool) []*rule.Rule {
	return nil
}

func rulesForTestTarget(dumpt *spdump.Target, desct *spdesc.Target, shouldSetVis bool) []*rule.Rule {
	return nil
}
