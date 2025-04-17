package swiftbin_test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/jsonutils"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftbin"
	"github.com/stretchr/testify/assert"
)

func TestSwiftBin(t *testing.T) {
	t.Run("init package, dump, and describe", func(t *testing.T) {
		// Create temp dir
		dir, err := os.MkdirTemp("", "swiftbin")
		assert.NoError(t, err)
		defer os.RemoveAll(dir)

		// Create a build directory
		buildDir, err := os.MkdirTemp("", "builddir")
		assert.NoError(t, err)
		defer os.RemoveAll(buildDir)

		// Find Swift
		binPath, err := swiftbin.FindSwiftBinPath()
		assert.NoError(t, err)
		sb := swiftbin.NewSwiftBin(binPath)

		// Init a package
		pkgName := "MyPackage"
		err = sb.InitPackage(dir, pkgName, "library")
		assert.NoError(t, err)

		// Dump the package
		out, err := sb.DumpPackage(dir, buildDir)
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

	t.Run("package resolve", func(t *testing.T) {
		// Create temp dir
		dir, err := os.MkdirTemp("", "swiftbin")
		assert.NoError(t, err)
		defer os.RemoveAll(dir)

		// Create a build directory
		buildDir, err := os.MkdirTemp("", "builddir")
		assert.NoError(t, err)
		defer os.RemoveAll(buildDir)

		// Find Swift
		binPath, err := swiftbin.FindSwiftBinPath()
		assert.NoError(t, err)
		sb := swiftbin.NewSwiftBin(binPath)

		// Init a package
		pkgName := "MyPackage"
		err = sb.InitPackage(dir, pkgName, "library")
		assert.NoError(t, err)

		// Write a package manfiest
		manifestPath := filepath.Join(dir, "Package.swift")
		err = os.WriteFile(manifestPath, []byte(pkgManifestWithExtDep), 0666)
		assert.NoError(t, err)

		// Resolve the package
		err = sb.ResolvePackage(dir, buildDir, false)
		assert.NoError(t, err)
		resolvedPkgPath := filepath.Join(dir, "Package.resolved")
		assert.FileExists(t, resolvedPkgPath)

		// Resolve the package to their latest eligible version
		err = sb.ResolvePackage(dir, buildDir, true)
		assert.NoError(t, err)
	})
}

const pkgManifestWithExtDep = `
// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MyPackage",
    products: [
        .library(
            name: "MyPackage",
            targets: ["MyPackage"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", exact: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MyPackage",
            dependencies: []
        ),
        .testTarget(
            name: "MyPackageTests",
            dependencies: ["MyPackage"]
        ),
    ]
)
`
