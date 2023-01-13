package swiftpkg

import (
	"fmt"
	"sort"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdesc"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
)

// A PackageInfo encapsulates all of the information about a Swift package.
type PackageInfo struct {
	Name         string
	DisplayName  string
	Path         string
	ToolsVersion string
	Targets      Targets
	Platforms    []*Platform
	Products     []*Product
	Dependencies []*Dependency
}

// NewPackageInfo returns the Swift package information from a Swift package on disk.
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

	platforms := make([]*Platform, len(descManifest.Platforms))
	for idx, p := range descManifest.Platforms {
		platforms[idx] = NewPlatfromFromManifestInfo(&p)
	}

	products := make([]*Product, len(dumpManifest.Products))
	for idx, p := range dumpManifest.Products {
		products[idx], err = NewProductFromManifestInfo(&p)
		if err != nil {
			return nil, fmt.Errorf("failed to create product for %v: %w", p.Name, err)
		}
	}

	deps := make([]*Dependency, len(dumpManifest.Dependencies))
	for idx, d := range dumpManifest.Dependencies {
		deps[idx], err = NewDependencyFromManifestInfo(&d)
		if err != nil {
			return nil, fmt.Errorf("failed to create dependency: %w", err)
		}
	}

	return &PackageInfo{
		Name:         descManifest.Name,
		DisplayName:  descManifest.ManifestDisplayName,
		Path:         descManifest.Path,
		ToolsVersion: descManifest.ToolsVersion,
		Targets:      targets,
		Platforms:    platforms,
		Products:     products,
		Dependencies: deps,
	}, nil
}

// ProductReferences returns a uniq slice of the product references used in the manifest.
func (pi *PackageInfo) ProductReferences() []*ProductReference {
	prs := make(map[string]*ProductReference)

	addProdRef := func(pr *ProductReference) {
		if pr == nil {
			return
		}
		uk := pr.UniqKey()
		if _, ok := prs[uk]; !ok {
			prs[uk] = pr
		}
	}

	for _, t := range pi.Targets {
		for _, td := range t.Dependencies {
			addProdRef(td.Product)
		}
	}

	keys := make([]string, 0, len(prs))
	for k := range prs {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	result := make([]*ProductReference, 0, len(prs))
	for _, k := range keys {
		result = append(result, prs[k])
	}
	return result
}
