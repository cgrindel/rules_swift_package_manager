package swiftpkg

import (
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
)

type PackageInfo struct {
	// Package directory
	Dir string

	// The manifest information 
	Manifest *Manifest
}

func NewPackageInfo(sw swiftbin.Executor, dir string) (*PackageInfo, error) {
	dump, err := sw.DumpPackage(dir)
	if err != nil {
		return nil, err
	}
	manifest, err := NewManifestFromJSON(dump)
	if err != nil {
		return nil, err
	}

	return &PackageInfo{
		Dir: dir,
		Manifest: manifest,
	}, nil
}
