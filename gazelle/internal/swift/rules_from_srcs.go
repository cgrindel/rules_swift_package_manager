package swift

import (
	"path/filepath"
	"sort"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	mapset "github.com/deckarep/golang-set/v2"
)

// RulesFromSrcs returns the Bazel build rule declarations for the provided source files.
func RulesFromSrcs(args language.GenerateArgs, srcs []string) []*rule.Rule {
	fileInfos := NewFileInfosFromRelPaths(args.Dir, srcs)
	swiftImports, moduleType := collectSwiftInfo(fileInfos)

	moduleName := filepath.Base(args.Rel)
	if moduleName == "." {
		moduleName = args.Config.RepoName
	}
	shouldSetVis := shouldSetVisibility(args)

	var rules []*rule.Rule
	switch moduleType {
	case LibraryModuleType:
		rules = rulesForLibraryModule(moduleName, srcs, swiftImports, shouldSetVis, args.File)
	case BinaryModuleType:
		rules = rulesForBinaryModule(moduleName, srcs, swiftImports, shouldSetVis, args.File)
	case TestModuleType:
		rules = rulesForTestModule(moduleName, srcs, swiftImports, shouldSetVis, args.File)
	}
	return rules
}

var guiModules = mapset.NewSet[string]("AppKit", "UIKit", "SwiftUI")

// Returns the imports and the module typ
func collectSwiftInfo(fileInfos []*FileInfo) ([]string, ModuleType) {
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
