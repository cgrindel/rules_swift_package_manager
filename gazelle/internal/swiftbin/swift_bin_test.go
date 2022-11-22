package swiftbin_test

import (
	"encoding/json"
	"os"
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonutils"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/stretchr/testify/assert"
)

func TestSwiftBin(t *testing.T) {
	t.Run("init package, dump, and describe", func(t *testing.T) {
		// Create temp dir
		dir, err := os.MkdirTemp("", "swiftbin")
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

		// Dump the package
		out, err := sb.DumpPackage(dir)
		assert.NoError(t, err)
		var dumpMap map[string]any
		err = json.Unmarshal(out, &dumpMap)
		assert.NoError(t, err)
		actualPkgName, err := jsonutils.StringAtKey(dumpMap, "name")
		assert.NoError(t, err)
		assert.Equal(t, pkgName, actualPkgName)

		// Describe the package
		out, err = sb.DescribePackage(dir)
		assert.NoError(t, err)
		var descMap map[string]any
		err = json.Unmarshal(out, &descMap)
		assert.NoError(t, err)
		actualPkgName, err = jsonutils.StringAtKey(descMap, "name")
		assert.NoError(t, err)
		assert.Equal(t, pkgName, actualPkgName)
	})
}
