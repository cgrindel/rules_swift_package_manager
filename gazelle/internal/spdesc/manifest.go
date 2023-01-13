// Package spdesc provides types and utility functions for reading Swift package description JSON.
package spdesc

import (
	"encoding/json"
	"path/filepath"
)

// The JSON formats described in this file are for the `swift package describe --type json` JSON output.

// NewManifestFromJSON creates a Swift manifest from description JSON.
func NewManifestFromJSON(bytes []byte) (*Manifest, error) {
	var manifest Manifest
	err := json.Unmarshal(bytes, &manifest)
	if err != nil {
		return nil, err
	}
	return &manifest, nil
}

// Manifest

// A Manifest represents the root of the description JSON. The members of the struct provide access
// to the Swift manifest parts.
type Manifest struct {
	Name                string
	ManifestDisplayName string `json:"manifest_display_name"`
	Path                string
	ToolsVersion        string `json:"tools_version"`
	Targets             Targets
	Platforms           []Platform
	Products            []Product
	Dependencies        []Dependency
}

// Targets

// Targets represents a slice of Swift targets.
type Targets []Target

// FindByName returns the Swift target that matches the provided name. It returns nil, if a match is
// not found.
func (ts Targets) FindByName(name string) *Target {
	for _, t := range ts {
		if t.Name == name {
			return &t
		}
	}
	return nil
}

// FindByPath returns the Swift target that matches the provided path. It returns nil, if a match is
// not found.
func (ts Targets) FindByPath(path string) *Target {
	for _, t := range ts {
		if t.Path == path {
			return &t
		}
	}
	return nil
}

// A Target represents a Swift target.
type Target struct {
	Name                string
	C99name             string `json:"c99name"`
	Type                string
	ModuleType          string `json:"module_type"`
	Path                string
	Sources             []string
	TargetDependencies  []string `json:"target_dependencies"`
	ProductDependencies []string `json:"product_dependencies"`
	ProductMemberships  []string `json:"product_memberships"`
}

// SourcesWithPath returns the sources prepended by the target's path.
func (t *Target) SourcesWithPath() []string {
	if t.Path == "" {
		return t.Sources
	}
	result := make([]string, len(t.Sources))
	for idx, src := range t.Sources {
		result[idx] = filepath.Join(t.Path, src)
	}
	return result
}

// Platforms

// A Platform represents a Swift package platform.
type Platform struct {
	Name    string
	Version string
}

// Product

// A ProductType is an enum that identifies the type of Swift product.
type ProductType int

const (
	UnknownProductType ProductType = iota
	ExecutableProductType
	LibraryProductType
	PluginProductType
)

func (pt *ProductType) UnmarshalJSON(b []byte) error {
	var anyMap map[string]any
	err := json.Unmarshal(b, &anyMap)
	if err != nil {
		return err
	}
	if _, ok := anyMap["executable"]; ok {
		*pt = ExecutableProductType
	} else if _, ok = anyMap["library"]; ok {
		*pt = LibraryProductType
	} else if _, ok = anyMap["plugin"]; ok {
		*pt = PluginProductType
	}
	return nil
}

// A Product represents a Swift product.
type Product struct {
	Name    string
	Targets []string
	Type    ProductType
}

// Dependency

// A Dependency represents a Swift external dependency.
type Dependency struct {
	Identity    string
	Type        string
	URL         string
	Requirement DependencyRequirement
}

// Requirement

// A DependencyRequirement represents the eligibility requirements for an external dependency.
type DependencyRequirement struct {
	Range []VersionRange
}

// A VersionRange represents an upper and lower bound for the elgibility of an external dependency.
type VersionRange struct {
	LowerBound string `json:"lower_bound"`
	UpperBound string `json:"upper_bound"`
}
