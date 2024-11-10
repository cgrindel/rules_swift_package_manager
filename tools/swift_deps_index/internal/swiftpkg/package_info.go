package swiftpkg

import (
	"encoding/json"
	"fmt"
	"sort"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spdesc"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spdump"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftbin"
	mapset "github.com/deckarep/golang-set/v2"
)

// A PackageInfo encapsulates all of the information about a Swift package.
type PackageInfo struct {
	Name                string       `json:"name"`
	DisplayName         string       `json:"-"`
	Path                string       `json:"path"`
	ToolsVersion        string       `json:"tools_version"`
	Targets             Targets      `json:"targets"`
	Platforms           []*Platform  `json:"platforms"`
	Products            []*Product   `json:"products"`
	Dependencies        Dependencies `json:"dependencies"`
	CLanguageStandard   string       `json:"-"`
	CxxLanguageStandard string       `json:"-"`
}

func NewPackageInfoFromJSON(bytes []byte) (*PackageInfo, error) {
	var pi PackageInfo
	err := json.Unmarshal(bytes, &pi)
	if err != nil {
		return nil, err
	}
	return &pi, nil
}

// NewPackageInfo returns the Swift package information from a Swift package on disk.
func NewPackageInfo(sw swiftbin.Executor, dir, buildDir string) (*PackageInfo, error) {
	dump, err := sw.DumpPackage(dir, buildDir)
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

	// We are purposefully only using the products from the dump JSON. The description JSON can
	// include phantom products. These are products that were not explicilty defined in the manifest,
	// but were inferred from targets. The swift-nio package manifest
	// (https://github.com/apple/swift-nio/blob/main/Package.swift) in the ios_sim example
	// demonstrates this behavior.
	products := make([]*Product, len(dumpManifest.Products))
	for idx, p := range dumpManifest.Products {
		products[idx], err = NewProductFromManifestInfo(&p)
		if err != nil {
			return nil, fmt.Errorf("failed to create product for %v: %w", p.Name, err)
		}
	}
	prodNames := mapset.NewSet[string]()
	for _, p := range products {
		prodNames.Add(p.Name)
	}

	targets := make([]*Target, 0, len(descManifest.Targets))
	for _, descT := range descManifest.Targets {
		dumpT := dumpManifest.Targets.FindByName(descT.Name)
		if dumpT == nil {
			// Ignore phantom targets (i.e., appear in description but not in the dump)
			continue
		}
		t, err := NewTargetFromManifestInfo(dir, &descT, dumpT, prodNames)
		if err != nil {
			return nil, fmt.Errorf("failed to create target for %s: %w", descT.Name, err)
		}
		// Only index targets that have at least one product membership.
		if len(t.ProductMemberships) > 0 {
			targets = append(targets, t)
		}
	}

	platforms := make([]*Platform, len(descManifest.Platforms))
	for idx, p := range descManifest.Platforms {
		platforms[idx] = NewPlatfromFromManifestInfo(&p)
	}

	// Collect a unique set of dependencies by dependency Identity.
	depsByID := make(map[string]*Dependency)
	for _, d := range dumpManifest.Dependencies {
		dep, err := NewDependencyFromManifestInfo(&d)
		if err != nil {
			return nil, fmt.Errorf("failed to create dependency: %w", err)
		}
		depID := dep.Identity()
		if _, ok := depsByID[depID]; !ok {
			depsByID[depID] = dep
		}
	}

	// A file system dep may have its own file system deps. We need to find those, as well and add
	// them to our set of dependencies. We recursively check for other file system deps in a
	// separate loop so that the top-level package's definition for the dependency takes precedence.
	for _, dep := range depsByID {
		if dep.FileSystem == nil {
			continue
		}
		depPkgInfo, err := NewPackageInfo(sw, dep.FileSystem.Path, buildDir)
		if err != nil {
			return nil, err
		}
		for _, depDep := range depPkgInfo.Dependencies {
			if depDep.FileSystem == nil {
				continue
			}
			depID := depDep.Identity()
			if _, ok := depsByID[depID]; !ok {
				depsByID[depID] = depDep
			}
		}
	}

	// Create a slice of the depdencies that were found.
	deps := make([]*Dependency, 0, len(depsByID))
	for _, dep := range depsByID {
		deps = append(deps, dep)
	}

	return &PackageInfo{
		Name:                descManifest.Name,
		DisplayName:         descManifest.ManifestDisplayName,
		Path:                descManifest.Path,
		ToolsVersion:        descManifest.ToolsVersion,
		Targets:             targets,
		Platforms:           platforms,
		Products:            products,
		Dependencies:        deps,
		CLanguageStandard:   dumpManifest.CLanguageStandard,
		CxxLanguageStandard: dumpManifest.CxxLanguageStandard,
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
