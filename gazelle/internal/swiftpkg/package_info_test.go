package swiftpkg_test

import (
	"os"
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestPackageInfo(t *testing.T) {
	t.Run("create", func(t *testing.T) {
		// Create temp dir
		dir, err := os.MkdirTemp("", "swiftpkg")
		assert.NoError(t, err)
		defer os.RemoveAll(dir)

		// Find Swift
		binPath, err := swiftbin.FindSwiftBinPath()
		assert.NoError(t, err)
		sb := swiftbin.NewSwiftBin(binPath)

		// Init a package
		pkgName := "MyPackage"
		err = sb.InitPackage(dir, pkgName, "library")
		assert.NoError(t, err)

		pi, err := swiftpkg.NewPackageInfo(sb, dir)
		assert.NoError(t, err)
		assert.Equal(t, dir, pi.Dir)
		assert.Equal(t, pkgName, pi.DumpManifest.Name)
		assert.Equal(t, pkgName, pi.DescManifest.Name)
	})
}
