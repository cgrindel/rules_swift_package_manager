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
		assert.Equal(t, pkgName, pi.Name)
	})
}

func TestManifestProductReferences(t *testing.T) {
	m := swiftpkg.PackageInfo{
		Targets: []*swiftpkg.Target{
			&swiftpkg.Target{
				Dependencies: []*swiftpkg.TargetDependency{
					&swiftpkg.TargetDependency{Product: &swiftpkg.ProductReference{ProductName: "Foo", Identity: "repoA"}},
					&swiftpkg.TargetDependency{Product: &swiftpkg.ProductReference{ProductName: "Bar", Identity: "repoA"}},
					&swiftpkg.TargetDependency{Product: &swiftpkg.ProductReference{ProductName: "Chicken", Identity: "repoB"}},
				},
			},
			&swiftpkg.Target{
				Dependencies: []*swiftpkg.TargetDependency{
					&swiftpkg.TargetDependency{Product: &swiftpkg.ProductReference{ProductName: "Foo", Identity: "repoA"}},
					&swiftpkg.TargetDependency{Product: &swiftpkg.ProductReference{ProductName: "Smidgen", Identity: "repoB"}},
				},
			},
		},
	}

	actual := m.ProductReferences()
	expected := []*swiftpkg.ProductReference{
		&swiftpkg.ProductReference{ProductName: "Bar", Identity: "repoA"},
		&swiftpkg.ProductReference{ProductName: "Foo", Identity: "repoA"},
		&swiftpkg.ProductReference{ProductName: "Chicken", Identity: "repoB"},
		&swiftpkg.ProductReference{ProductName: "Smidgen", Identity: "repoB"},
	}
	assert.Equal(t, expected, actual)
}
