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
		rules = rulesForTestModule(moduleName, srcs, swiftImports, shouldSetVis, args.File)
	}
	return rules
}

// Returns the imports and the module typ
func collectSwiftInfo(fileInfos []*FileInfo) ([]string, ModuleType) {
	hasTestFiles := false
	hasMain := false
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
		if fi.IsTest {
			hasTestFiles = true
		}
		if fi.ContainsMain {
			hasMain = true
		}
	}

	// Adjust the rule kind, if necessary
	// Check for test files first. On Linux, a main.swift is necessary for swift_test rules.
	if hasTestFiles {
		moduleType = TestModuleType
	} else if hasMain {
		moduleType = BinaryModuleType
	}

	sort.Strings(swiftImports)
	return swiftImports, moduleType
}
