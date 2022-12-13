package swift

import (
	"log"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

func RulesForSwiftProducts(args language.GenerateArgs, pi *swiftpkg.PackageInfo) []*rule.Rule {
	var rules []*rule.Rule
	for _, prd := range pi.DumpManifest.Products {
		prdRules := rulesForSwiftProduct(args, pi, &prd)
		rules = append(rules, prdRules...)
	}
	return rules
}

func rulesForSwiftProduct(
	args language.GenerateArgs,
	pi *swiftpkg.PackageInfo,
	product *spdump.Product,
) []*rule.Rule {
	if len(product.Targets) == 0 {
		log.Printf("No targets found in product %s while generating rules.", product.Name)
		return nil
	}
	targetName := product.Targets[0]
	target := pi.DescManifest.Targets.FindByName(targetName)
	if target == nil {
		log.Printf("Target with name %s not found while generating rules for %s product.",
			targetName, product.Name)
		return nil
	}
	actual := BazelLabelFromTarget("", target)
	r := aliasRule(product.Name, actual)
	return []*rule.Rule{r}
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
