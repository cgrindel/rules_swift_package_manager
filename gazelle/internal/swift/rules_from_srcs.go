package swift

import (
	"sort"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swiftpkg"
	mapset "github.com/deckarep/golang-set/v2"
)

// RulesFromSrcs returns the Bazel build rule declarations for the provided source files.
func RulesFromSrcs(
	args language.GenerateArgs,
	srcs []string,
	defaultModuleName string,
) []*rule.Rule {
	fileInfos := swiftpkg.NewSwiftFileInfosFromRelPaths(args.Dir, srcs)
	swiftImports, moduleType := collectSwiftInfo(fileInfos)

	shouldSetVis := shouldSetVisibility(args)

	var rules []*rule.Rule
	switch moduleType {
	case LibraryModuleType:
		rules = rulesForLibraryModule(defaultModuleName, srcs, swiftImports, shouldSetVis, args.File)
	case BinaryModuleType:
		rules = rulesForBinaryModule(defaultModuleName, srcs, swiftImports, shouldSetVis, args.File)
	case TestModuleType:
		rules = rulesForTestModule(defaultModuleName, srcs, swiftImports, shouldSetVis, args.File)
	}
	return rules
}

var guiModules = mapset.NewSet("AppKit", "UIKit", "SwiftUI")

// Returns the imports and the module typ
func collectSwiftInfo(fileInfos []*swiftpkg.SwiftFileInfo) ([]string, ModuleType) {
	importsGUIModules := false
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
			if !importsGUIModules && guiModules.Contains(imp) {
				importsGUIModules = true
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
	// GUI applications can use the @main directive. So, we need to see if the module contains any
	// of the GUI related modules. If no GUI modules and it has a main, then create a swift_binary.
	if hasTestFiles {
		moduleType = TestModuleType
	} else if hasMain && !importsGUIModules {
		moduleType = BinaryModuleType
	}

	sort.Strings(swiftImports)
	return swiftImports, moduleType
}
