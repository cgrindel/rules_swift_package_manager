package swift

import (
	"path/filepath"
	"sort"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
	mapset "github.com/deckarep/golang-set/v2"
)

// RulesFromSrcs returns the Bazel build rule declarations for the provided source files.
func RulesFromSrcs(args language.GenerateArgs, srcs []string) []*rule.Rule {
	fileInfos := NewFileInfosFromRelPaths(args.Dir, srcs)
	swiftImports, moduleType := collectSwiftInfo(fileInfos)

	defaultModuleName := defaultModuleName(args)
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

func defaultModuleName(args language.GenerateArgs) string {
	// Order of names to use
	// 1. Value specified via directive.
	// 2. Directory name.
	// 3. Repository name.
	// 4. "DefaultModule"

	// Check for a value configured via directive
	sc := swiftcfg.GetSwiftConfig(args.Config)
	if defaultModuleName, ok := sc.DefaultModuleNames[args.Rel]; ok {
		return defaultModuleName
	}
	defaultModuleName := filepath.Base(args.Config.WorkDir)
	if defaultModuleName == "." || defaultModuleName == "" {
		defaultModuleName = args.Config.RepoName
	}
	if defaultModuleName == "" {
		defaultModuleName = "DefaultModule"
	}
	return defaultModuleName
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
