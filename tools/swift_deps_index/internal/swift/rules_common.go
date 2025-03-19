package swift

import (
	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

// Rule Creation

func rulesForLibraryModule(
	defaultName string,
	defaultModuleName string,
	srcs []string,
	swiftImports []string,
	shouldSetVis bool,
	swiftLibraryTags []string,
	buildFile *rule.File,
) []*rule.Rule {
	name, moduleName := ruleNameAndModuleName(buildFile, LibraryRuleKind, defaultName, defaultModuleName)
	r := rule.NewRule(LibraryRuleKind, name)
	setCommonSwiftAttrs(r, moduleName, srcs, swiftImports)
	setVisibilityAttr(r, shouldSetVis, []string{"//visibility:public"})
	if len(swiftLibraryTags) > 0 {
		r.SetAttr("tags", swiftLibraryTags)
	}

	return []*rule.Rule{r}
}

func rulesForBinaryModule(
	defaultName string,
	defaultModuleName string,
	srcs []string,
	swiftImports []string,
	shouldSetVis bool,
	buildFile *rule.File,
) []*rule.Rule {
	name, moduleName := ruleNameAndModuleName(buildFile, BinaryRuleKind, defaultName, defaultModuleName)
	r := rule.NewRule(BinaryRuleKind, name)
	setCommonSwiftAttrs(r, moduleName, srcs, swiftImports)
	setVisibilityAttr(r, shouldSetVis, []string{"//visibility:public"})
	return []*rule.Rule{r}
}

func rulesForTestModule(
	defaultName string,
	defaultModuleName string,
	srcs []string,
	swiftImports []string,
	shouldSetVis bool,
	buildFile *rule.File,
) []*rule.Rule {
	// Detect the type of rule that should be used to build the Swift sources.
	r := buildRuleForTestSrcs(buildFile, defaultName, defaultModuleName)
	setCommonSwiftAttrs(r, defaultModuleName, srcs, swiftImports)
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

// Name and Module Name

// Determine the rule name and module name from existing rules
func ruleNameAndModuleName(buildFile *rule.File, kind, defaultName, defaultModuleName string) (string, string) {
	var existingRules []*rule.Rule
	if buildFile != nil {
		existingRules = findRulesByKind(buildFile.Rules, kind)
	}
	// If we found a single swift_binary, use its name. Otherwise, just use the module name.
	var name, moduleName string
	if len(existingRules) == 1 {
		first := existingRules[0]
		name = first.Name()
		moduleName = first.AttrString(ModuleNameAttrName)
	} else {
		name = defaultName
		moduleName = defaultModuleName
	}
	return name, moduleName
}
