package swift

import "golang.org/x/exp/slices"

var builtInModules = []string{
	"Foundation",
	"XCTest",
}

// IsBuiltInModule determines if the module is built into the Swift standard library.
func IsBuiltInModule(name string) bool {
	return slices.Contains(builtInModules, name)
}
