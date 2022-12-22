package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

const pkgDir = "/path/to/pkg"

func TestCodeDirForRemotePackage(t *testing.T) {
	url := "https://github.com/nicklockwood/SwiftFormat"
	actual := swift.CodeDirForRemotePackage(pkgDir, url)
	expected := "/path/to/pkg/.build/checkouts/SwiftFormat"
	assert.Equal(t, expected, actual)
}

func TestCodeDirForLocalPackage(t *testing.T) {
	t.Run("with absolute local path", func(t *testing.T) {
		localPkgPath := "/path/to/local_pkg"
		actual := swift.CodeDirForLocalPackage(pkgDir, localPkgPath)
		expected := localPkgPath
		assert.Equal(t, expected, actual)
	})
	t.Run("with relative local path", func(t *testing.T) {
		localPkgPath := "../local_pkg"
		actual := swift.CodeDirForLocalPackage(pkgDir, localPkgPath)
		expected := "/path/to/local_pkg"
		assert.Equal(t, expected, actual)
	})
}
