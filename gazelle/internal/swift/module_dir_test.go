package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestModuleRootDir(t *testing.T) {
	t.Run("path contains module parent directory", func(t *testing.T) {
		actual := swift.ModuleDir("Sources/Chicken")
		assert.Equal(t, "Sources/Chicken", actual)

		actual = swift.ModuleDir("foo/Source/Chicken")
		assert.Equal(t, "foo/Source/Chicken", actual)

		actual = swift.ModuleDir("foo/Sources/Chicken/Panther")
		assert.Equal(t, "foo/Sources/Chicken", actual)

		actual = swift.ModuleDir("Tests/ChickenTests/PantherTests")
		assert.Equal(t, "Tests/ChickenTests", actual)
	})
	t.Run("path does not contain module parent directory", func(t *testing.T) {
		actual := swift.ModuleDir("foo/Chicken")
		assert.Equal(t, "foo/Chicken", actual)
	})
}
