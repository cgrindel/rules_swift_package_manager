package swift

import (
	"path/filepath"
	"sort"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

func RulesFromSrcs(args language.GenerateArgs, srcs []string) []*rule.Rule {
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

