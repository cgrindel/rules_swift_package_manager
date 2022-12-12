package spdesc

import (
	"encoding/json"
	"fmt"
	"path/filepath"
)

// The JSON formats described in this file are for the `swift package describe --type json` JSON output.

func NewManifestFromJSON(bytes []byte) (*Manifest, error) {
	var manifest Manifest
	err := json.Unmarshal(bytes, &manifest)
	if err != nil {
		return nil, err
	}
	return &manifest, nil
}

// Manifest

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

type Targets []Target

func (ts Targets) FindByName(name string) *Target {
	for _, t := range ts {
		if t.Name == name {
			return &t
		}
	}
	return nil
}

func (ts Targets) FindByPath(path string) *Target {
	for _, t := range ts {
		if t.Path == path {
			return &t
		}
	}
	return nil
}

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

type Platform struct {
	Name    string
	Version string
}

// Product

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

type Product struct {
	Name    string
	Targets []string
	Type    ProductType
}

// Dependency

type Dependency struct {
	Identity    string
	Type        string
	URL         string
	Requirement DependencyRequirement
}

// Requirement

type DependencyRequirement struct {
	Range []VersionRange
}

type VersionRange struct {
	LowerBound string `json:"lower_bound"`
	UpperBound string `json:"upper_bound"`
}

// Module from Product

func (m *Manifest) ProductModules() ([]string, error) {
	var err error
	modules := make([]string, len(m.Products))
	for idx, prd := range m.Products {
		if modules[idx], err = m.moduleForProduct(&prd); err != nil {
			return nil, err
		}
	}
	return modules, nil
}

func (m *Manifest) moduleForProduct(p *Product) (string, error) {
	if len(p.Targets) == 0 {
		return "", fmt.Errorf("product %s has not targets", p.Name)
	}
	targetName := p.Targets[0]
	t := m.Targets.FindByName(targetName)
	if t == nil {
		return "", fmt.Errorf("target %s not found while finding product module", targetName)
	}
	return t.C99name, nil
}
