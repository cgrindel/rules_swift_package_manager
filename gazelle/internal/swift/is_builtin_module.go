package swift

import "golang.org/x/exp/slices"

var builtInModules = []string{
	"Foundation",
	"XCTest",
}

func IsBuiltInModule(name string) bool {
	return slices.Contains(builtInModules, name)
}
