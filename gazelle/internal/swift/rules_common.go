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
	setCommonSwiftAttrs(r, moduleName, srcs, swiftImports)
	setVisibilityAttr(r, shouldSetVis, []string{"//visibility:public"})
	return []*rule.Rule{r}
}

func rulesForBinaryModule(
	moduleName string,
	srcs []string,
	swiftImports []string,
	shouldSetVis bool,
) []*rule.Rule {
	r := rule.NewRule(BinaryRuleKind, moduleName)
	setCommonSwiftAttrs(r, moduleName, srcs, swiftImports)
	setVisibilityAttr(r, shouldSetVis, []string{"//visibility:public"})
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
	setCommonSwiftAttrs(r, moduleName, srcs, swiftImports)
	return []*rule.Rule{r}
}

func setCommonSwiftAttrs(r *rule.Rule, moduleName string, srcs []string, swiftImports []string) {
	if moduleName != "" {
		r.SetAttr(ModuleNameAttrName, moduleName)
	}
	if srcs != nil {
		r.SetAttr("srcs", srcs)
	}
	r.SetPrivateAttr(config.GazelleImportsKey, swiftImports)
}

// Alias

func aliasRule(name, actual string) *rule.Rule {
	r := rule.NewRule(AliasRuleKind, name)
	r.SetAttr("actual", actual)
	return r
}

// Visibility

func shouldSetVisibility(args language.GenerateArgs) bool {
	// If the package has a default visibility set, do not set visibility
	if args.File != nil && args.File.HasDefaultVisibility() {
		return false
	}
	return true
}

func setVisibilityAttr(r *rule.Rule, shouldSetVis bool, visibility []string) {
	if !shouldSetVis || visibility == nil {
		return
	}
	r.SetAttr("visibility", visibility)
}
