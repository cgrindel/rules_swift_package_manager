package swift

import mapset "github.com/deckarep/golang-set/v2"

var otherBuiltinModules = mapset.NewSet[string](
	"XCTest",
)

// The list of frameworks is found in builtin_modules.go.
var allBuiltInModules = otherBuiltinModules.Union(macosFrameworks.Union(iosFrameworks))

// IsBuiltInModule determines if the module is built into the Swift standard library.
func IsBuiltInModule(name string) bool {
	return allBuiltInModules.Contains(name)
}
