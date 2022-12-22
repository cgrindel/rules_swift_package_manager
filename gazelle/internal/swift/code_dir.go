package swift

import (
	"path"
	"path/filepath"
	"strings"
)

const swiftPkgBuildDirname = ".build"
const swiftPkgCheckoutsDirname = "checkouts"

// Returns the path to the dependency's code. For source control dependencies, it is the checkout
// directory.
func CodeDirForRemotePackage(pkgDir string, url string) string {
	// Return the checkout directory
	return filepath.Join(
		pkgDir,
		swiftPkgBuildDirname,
		swiftPkgCheckoutsDirname,
		spmCheckoutDirname(url),
	)
}

func spmCheckoutDirname(url string) string {
	base := path.Base(url)
	ext := path.Ext(base)
	if ext == "" {
		return base
	}
	return strings.TrimSuffix(base, ext)
}

// Returns the path to the dependency's code. For local packages, it is the path to the local package.
func CodeDirForLocalPackage(pkgDir string, localPkgPath string) string {
	var path string
	if filepath.IsAbs(localPkgPath) {
		path = localPkgPath
	} else {
		path = filepath.Join(pkgDir, localPkgPath)
	}
	// Return the local path
	return filepath.Clean(path)
}
