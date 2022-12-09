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
	r := rule.NewRule(BinaryRuleKind, moduleName)
	setCommonAttrs(r, moduleName, srcs, swiftImports, shouldSetVis, []string{"//visibility:public"})
	// Swift treats single file binary compilations differently. We need to tell Swift to compile
	// the single file as a library.
	if len(srcs) == 1 && srcs[0] != "main.swift" {
		r.SetAttr("copts", []string{"-parse-as-library"})
	}
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
	if moduleName != "" {
		r.SetAttr(ModuleNameAttrName, moduleName)
	}
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
