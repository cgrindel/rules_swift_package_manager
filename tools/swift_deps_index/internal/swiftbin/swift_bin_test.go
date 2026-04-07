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
	t.Run("dump and describe include Bazel-only local dependencies", func(t *testing.T) {
		baseDir, err := os.MkdirTemp("", "swiftbin")
		assert.NoError(t, err)
		defer os.RemoveAll(baseDir)

		rootDir := filepath.Join(baseDir, "RootPkg")
		localDepDir := filepath.Join(baseDir, "LocalDep")
		assert.NoError(t, os.MkdirAll(rootDir, 0o755))
		assert.NoError(t, os.MkdirAll(localDepDir, 0o755))

		binPath, err := swiftbin.FindSwiftBinPath()
		assert.NoError(t, err)
		sb := swiftbin.NewSwiftBin(binPath)

		assert.NoError(t, sb.InitPackage(localDepDir, "LocalDep", "library"))
		assert.NoError(t, sb.InitPackage(rootDir, "RootPkg", "library"))

		manifestPath := filepath.Join(rootDir, "Package.swift")
		err = os.WriteFile(
			manifestPath,
			[]byte(pkgManifestWithBazelLocalDep),
			0o666,
		)
		assert.NoError(t, err)

		out, err := sb.DumpPackage(rootDir, "")
		assert.NoError(t, err)
		var dumpMap map[string]any
		assert.NoError(t, json.Unmarshal(out, &dumpMap))
		dumpDeps, ok := dumpMap["dependencies"].([]any)
		if assert.True(t, ok, "dump-package dependencies should be an array") {
			assert.Len(t, dumpDeps, 1)
			depMap, ok := dumpDeps[0].(map[string]any)
			if assert.True(t, ok, "dump-package dependency should be a map") {
				depJSON, err := json.Marshal(depMap)
				assert.NoError(t, err)
				assert.Contains(t, string(depJSON), "LocalDep")
			}
		}

		out, err = sb.DescribePackage(rootDir)
		assert.NoError(t, err)
		var descMap map[string]any
		assert.NoError(t, json.Unmarshal(out, &descMap))
		descDeps, ok := descMap["dependencies"].([]any)
		if assert.True(t, ok, "describe dependencies should be an array") {
			assert.Len(t, descDeps, 1)
			depMap, ok := descDeps[0].(map[string]any)
			if assert.True(t, ok, "describe dependency should be a map") {
				assert.Equal(t, "fileSystem", depMap["type"])
				actualPath, ok := depMap["path"].(string)
				if assert.True(t, ok, "describe dependency path should be a string") {
					expectedPath, err := filepath.EvalSymlinks(localDepDir)
					assert.NoError(t, err)
					actualPath, err = filepath.EvalSymlinks(actualPath)
					assert.NoError(t, err)
					assert.Equal(t, expectedPath, actualPath)
				}
			}
		}
	})

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

const pkgManifestWithBazelLocalDep = `
// swift-tools-version: 5.7

import PackageDescription

let dependencies: [Package.Dependency] = {
    #if BAZEL
    return [
        .package(path: "../LocalDep"),
    ]
    #else
    return []
    #endif
}()

let package = Package(
    name: "RootPkg",
    dependencies: dependencies,
    targets: [
        .target(
            name: "RootPkg",
            dependencies: [
                .product(name: "LocalDep", package: "LocalDep"),
            ]
        ),
    ]
)
`
