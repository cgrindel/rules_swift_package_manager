package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestModuleRootDir(t *testing.T) {
	tests := []struct {
		path string
		wval string
	}{
		{path: "Sources/Chicken", wval: "Sources/Chicken"},
		{path: "foo/Source/Chicken", wval: "foo/Source/Chicken"},
		{path: "foo/Sources/Chicken/Panther", wval: "foo/Sources/Chicken"},
		{path: "Tests/ChickenTests/PantherTests", wval: "Tests/ChickenTests"},
		// path does not contain module directory
		{path: "foo/Chicken", wval: "foo/Chicken"},
	}
	for _, tc := range tests {
		actual := swift.ModuleDir(tc.path)
		assert.Equal(t, tc.wval, actual)
	}
}
