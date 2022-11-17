package swift

import (
	"fmt"
	"path/filepath"
	"sort"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

func Rules(args language.GenerateArgs, srcs []string) []*rule.Rule {
	fileInfos := NewFileInfosFromRelPaths(args.Dir, srcs)
	swiftImports, moduleType := collectSwiftInfo(fileInfos)

	moduleName := filepath.Base(args.Rel)
	shouldSetVis := shouldSetVisibility(args)

	var rules []*rule.Rule
	switch moduleType {
	case LibraryModuleType:
		rules = rulesForLibraryModule(moduleName, srcs, swiftImports, shouldSetVis)
	case BinaryModuleType:
		rules = rulesForBinaryModule(moduleName, srcs, swiftImports, shouldSetVis)
	case TestModuleType:
		rules = rulesForTestModule(moduleName, srcs, swiftImports, shouldSetVis)
	}

	return rules
}

// Returns the imports and the module typ
func collectSwiftInfo(fileInfos []*FileInfo) ([]string, ModuleType) {
	moduleType := LibraryModuleType
	swiftImports := make([]string, 0)
	swiftImportsSet := make(map[string]bool)
	for _, fi := range fileInfos {
		// Collect the imports
		for _, imp := range fi.Imports {
			if _, ok := swiftImportsSet[imp]; !ok {
				swiftImportsSet[imp] = true
				swiftImports = append(swiftImports, imp)
			}
		}

		// Adjust the rule kind, if necessary
		switch {
		case fi.ContainsMain:
			moduleType = BinaryModuleType
		case fi.IsTest:
			moduleType = TestModuleType
		}
	}
	sort.Strings(swiftImports)
	return swiftImports, moduleType
}

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
	libModName := fmt.Sprintf("%sLibrary", moduleName)
	libR := rule.NewRule(LibraryRuleKind, libModName)
	setCommonAttrs(libR, libModName, srcs, swiftImports, shouldSetVis, nil)

	binR := rule.NewRule(BinaryRuleKind, moduleName)
	setCommonAttrs(
		binR, moduleName, nil, []string{libModName}, shouldSetVis, []string{"//visibility:public"})

	return []*rule.Rule{libR, binR}
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
