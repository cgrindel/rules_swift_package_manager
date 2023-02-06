package swift

import mapset "github.com/deckarep/golang-set/v2"

var builtInModules = mapset.NewSet[string](
	"AppKit",
	"Foundation",
	"SwiftUI",
	"UIKit",
	"XCTest",
)

// IsBuiltInModule determines if the module is built into the Swift standard library.
func IsBuiltInModule(name string) bool {
	return builtInModules.Contains(name)
}
