package swiftpkg

import (
	"fmt"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdesc"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
)

type PackageInfo struct {
	// Package directory
	Dir string

	// Info from the dump
	DumpManifest *spdump.Manifest

	// Info from the describe
	DescManifest *spdesc.Manifest

	// Package attributes from manifests
	Name         string
	DisplayName  string
	Path         string
	ToolsVersion string
	Targets      Targets
	Platforms    []Platform
	Products     []Product
	Dependencies []Dependency
}

func NewPackageInfo(sw swiftbin.Executor, dir string) (*PackageInfo, error) {
	dump, err := sw.DumpPackage(dir)
	if err != nil {
		return nil, err
	}
	dumpManifest, err := spdump.NewManifestFromJSON(dump)
	if err != nil {
		return nil, err
	}

	desc, err := sw.DescribePackage(dir)
	if err != nil {
		return nil, err
	}
	descManifest, err := spdesc.NewManifestFromJSON(desc)
	if err != nil {
		return nil, err
	}

	targets := make([]*Target, len(descManifest.Targets))
	for idx, descT := range descManifest.Targets {
		dumpT := dumpManifest.Targets.FindByName(descT.Name)
		if dumpT == nil {
			return nil, fmt.Errorf("dump manifest info for %s target not found", descT.Name)
		}
		targets[idx], err = NewTargetFromManifestInfo(&descT, dumpT)
		if err != nil {
			return nil, fmt.Errorf("failed to create target for %s: %w", descT.Name, err)
		}
	}

	return &PackageInfo{
		// TODO(chuck): Remove Dir, DumpManifest, DescManifest
		Dir:          dir,
		DumpManifest: dumpManifest,
		DescManifest: descManifest,
		Name:         descManifest.Name,
		DisplayName:  descManifest.ManifestDisplayName,
		Path:         descManifest.Path,
		ToolsVersion: descManifest.ToolsVersion,
		Targets:      targets,
	}, nil
}
