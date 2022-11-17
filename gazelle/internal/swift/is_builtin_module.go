package swift

import (
	"github.com/cgrindel/swift_bazel/gazelle/internal/stringslices"
)

var builtInModules = []string{
	"Foundation",
	"XCTest",
}

func IsBuiltInModule(name string) bool {
	return stringslices.Contains(builtInModules, name)
}
