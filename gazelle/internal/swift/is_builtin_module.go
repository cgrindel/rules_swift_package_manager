package swift

import mapset "github.com/deckarep/golang-set/v2"

var otherBuiltinModules = mapset.NewSet[string](
	"RegexBuilder", // TODO: not included in System/Library/Frameworks for some reason
	"XCTest",
)

// The list of frameworks is found in builtin_modules.go.
var allBuiltInModuleSets = []mapset.Set[string]{
	otherBuiltinModules,
	macosFrameworks,
	iosFrameworks,
	tvosFrameworks,
	watchosFrameworks,
}

var allBuiltInModules mapset.Set[string]

func init() {
	allBuiltInModules = mapset.NewSet[string]()
	for _, mset := range allBuiltInModuleSets {
		allBuiltInModules = allBuiltInModules.Union(mset)
	}
}

// IsBuiltInModule determines if the module is built into the Swift standard library.
func IsBuiltInModule(name string) bool {
	return allBuiltInModules.Contains(name)
}
