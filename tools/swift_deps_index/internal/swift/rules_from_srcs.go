package swift

import (
	"sort"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	mapset "github.com/deckarep/golang-set/v2"
)

// RulesFromSrcs returns the Bazel build rule declarations for the provided source files.
func RulesFromSrcs(
	args language.GenerateArgs,
	srcs []string,
	defaultName string,
	defaultModuleName string,
	swiftLibraryTags []string,
) []*rule.Rule {
	fileInfos := swiftpkg.NewSwiftFileInfosFromRelPaths(args.Dir, srcs)
	swiftImports, moduleType := collectSwiftInfo(fileInfos)

	shouldSetVis := shouldSetVisibility(args)

	var rules []*rule.Rule
	switch moduleType {
	case LibraryModuleType:
		rules = rulesForLibraryModule(defaultName, defaultModuleName, srcs, swiftImports, shouldSetVis, swiftLibraryTags, args.File)
	case BinaryModuleType:
		rules = rulesForBinaryModule(defaultName, defaultModuleName, srcs, swiftImports, shouldSetVis, args.File)
	case TestModuleType:
		rules = rulesForTestModule(defaultName, defaultModuleName, srcs, swiftImports, shouldSetVis, args.File)
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

	// Adjust the rule kind, if necessary.
	// Check if this is a test module first. On Linux, a main.swift is necessary for swift_test rules.
	// rules_swift_package_manager does not currently support generating rules_apple targets.
	// However, applications using Apple's UI frameworks can use the @main directive.
	// To build these with rules_apple, we must first compile a swift_library target,
	// and then pass this as a dependency to the application or extension target.
	// So, we need to see if the module contains a main function and imports any of the GUI related modules.
	// If it does not import any GUI modules and it has a main, then create a swift_binary.
	if hasTestFiles {
		moduleType = TestModuleType
	} else if hasMain && !importsGUIModules {
		moduleType = BinaryModuleType
	}

	sort.Strings(swiftImports)
	return swiftImports, moduleType
}
