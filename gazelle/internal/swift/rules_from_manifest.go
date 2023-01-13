package swift

import (
	"log"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

// RulesForSwiftProducts returns the Bazel rule declarations for the provided Swift products.
func RulesForSwiftProducts(args language.GenerateArgs, pi *swiftpkg.PackageInfo) []*rule.Rule {
	var rules []*rule.Rule
	for _, prd := range pi.Products {
		prdRules := rulesForSwiftProduct(args, pi, prd)
		rules = append(rules, prdRules...)
	}
	return rules
}

func rulesForSwiftProduct(
	args language.GenerateArgs,
	pi *swiftpkg.PackageInfo,
	product *swiftpkg.Product,
) []*rule.Rule {
	if len(product.Targets) == 0 {
		log.Printf("No targets found in product %s while generating rules.", product.Name)
		return nil
	}
	targetName := product.Targets[0]
	target := pi.Targets.FindByName(targetName)
	if target == nil {
		log.Printf("Target with name %s not found while generating rules for %s product.",
			targetName, product.Name)
		return nil
	}
	lbl := BazelLabelFromTarget("", target)
	r := aliasRule(product.Name, lbl.String())
	return []*rule.Rule{r}
}

// RulesForSwiftTarget returns  the Bazel rule declaration for the specified Swift target.
func RulesForSwiftTarget(
	args language.GenerateArgs,
	pi *swiftpkg.PackageInfo,
	targetName string,
) []*rule.Rule {
	shouldSetVis := shouldSetVisibility(args)
	t := pi.Targets.FindByName(targetName)
	var rules []*rule.Rule
	switch t.Type {
	case swiftpkg.LibraryTargetType:
		rules = rulesForLibraryModule(t.Name, t.Sources, t.Imports(), shouldSetVis, args.File)
	case swiftpkg.ExecutableTargetType:
		rules = rulesForBinaryModule(t.Name, t.Sources, t.Imports(), shouldSetVis, args.File)
	case swiftpkg.TestTargetType:
		rules = rulesForTestModule(t.Name, t.Sources, t.Imports(), shouldSetVis, args.File)
	}
	return rules
}
