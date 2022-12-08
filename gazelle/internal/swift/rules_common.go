package swift

import (
	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

// Rule Creation

func rulesForLibraryModule(
	moduleName string,
	srcs []string,
	swiftImports []string,
	shouldSetVis bool,
) []*rule.Rule {
	r := rule.NewRule(LibraryRuleKind, moduleName)
	setCommonAttrs(r, moduleName, srcs, swiftImports, shouldSetVis, []string{"//visibility:public"})
	return []*rule.Rule{r}
}

func rulesForBinaryModule(
	moduleName string,
	srcs []string,
	swiftImports []string,
	shouldSetVis bool,
) []*rule.Rule {
	// libModName := fmt.Sprintf("%sLibrary", moduleName)
	// libR := rule.NewRule(LibraryRuleKind, libModName)
	// // libR.SetPrivateAttr(SwiftImportAs, [])
	// setCommonAttrs(libR, moduleName, srcs, swiftImports, shouldSetVis, nil)
	// binR := rule.NewRule(BinaryRuleKind, moduleName)
	// setCommonAttrs(
	// 	binR, moduleName, nil, []string{libModName}, shouldSetVis, []string{"//visibility:public"})
	// return []*rule.Rule{libR, binR}

	// Create a library target. We will create a binary target when this is referenced from an
	// executable product.
	r := rule.NewRule(LibraryRuleKind, moduleName)
	setCommonAttrs(r, moduleName, srcs, swiftImports, shouldSetVis, []string{"//visibility:public"})
	return []*rule.Rule{r}
}

func rulesForTestModule(
	moduleName string,
	srcs []string,
	swiftImports []string,
	shouldSetVis bool,
) []*rule.Rule {
	r := rule.NewRule(TestRuleKind, moduleName)
	setCommonAttrs(r, moduleName, srcs, swiftImports, shouldSetVis, nil)
	return []*rule.Rule{r}
}

func setCommonAttrs(
	r *rule.Rule,
	moduleName string,
	srcs []string,
	swiftImports []string,
	shouldSetVis bool,
	visibility []string,
) {
	r.SetAttr(ModuleNameAttrName, moduleName)
	if srcs != nil {
		r.SetAttr("srcs", srcs)
	}
	r.SetPrivateAttr(config.GazelleImportsKey, swiftImports)
	if shouldSetVis && visibility != nil {
		r.SetAttr("visibility", visibility)
	}
}

// Visibility

func shouldSetVisibility(args language.GenerateArgs) bool {
	// If the package has a default visibility set, do not set visibility
	if args.File != nil && args.File.HasDefaultVisibility() {
		return false
	}
	return true
}
