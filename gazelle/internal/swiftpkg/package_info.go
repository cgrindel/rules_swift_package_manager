package swiftpkg

import (
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
)

type PackageInfo struct {
	// Path to the Package.swift file
	ManifestPath string
	// Path to the Package.resolved file
	ResolvedPath string
}

func FindPackageInfo(dir string) (*PackageInfo, error) {
	// TODO(chuck): IMPLEMENT ME!
	return nil, nil
}

func (pi *PackageInfo) Resolve(sw swiftbin.Executor) error {
	// TODO(chuck): IMPLEMENT ME!
	return nil
}

func (pi *PackageInfo) Read(sw swiftbin.Executor) error {
	// TODO(chuck): IMPLEMENT ME!
	return nil
}
