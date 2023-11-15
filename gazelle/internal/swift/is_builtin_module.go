package swift

import mapset "github.com/deckarep/golang-set/v2"

var builtinTestFrameworks = mapset.NewSet[string](
	"XCTest",
)

// The list of frameworks is found in builtin_modules.go.
var allBuiltInFrameworkSets = []mapset.Set[string]{
	builtinTestFrameworks,
	macosFrameworks,
	iosFrameworks,
	tvosFrameworks,
	watchosFrameworks,
}

// The list of Swift modules is found in builtin_modules.go.
var allBuiltInSwiftModuleSets = []mapset.Set[string]{
	macosSwiftModules,
	iosSwiftModules,
	tvosSwiftModules,
	watchosSwiftModules,
}

var allBuiltInFrameworks mapset.Set[string]
var allBuiltInSwiftModules mapset.Set[string]

func init() {
	allBuiltInFrameworks = mapset.NewSet[string]()
	for _, s := range allBuiltInFrameworkSets {
		allBuiltInFrameworks = allBuiltInFrameworks.Union(s)
	}

	allBuiltInSwiftModules = mapset.NewSet[string]()
	for _, s := range allBuiltInSwiftModuleSets {
		allBuiltInSwiftModules = allBuiltInSwiftModules.Union(s)
	}
}

// IsBuiltInFramework determines if the module is built into the Swift standard library.
func IsBuiltInFramework(name string) bool {
	return allBuiltInFrameworks.Contains(name)
}

// IsBuiltInSwiftModule determines if the module is built into the Swift standard library.
func IsBuiltInSwiftModule(name string) bool {
	return allBuiltInSwiftModules.Contains(name)
}
