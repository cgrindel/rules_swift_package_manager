package spdesc

import "encoding/json"

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
	Targets             []Target
	Platforms           []Platform
	// Products           []Product
	// Dependencies       []Dependency
}

// Targets

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

// Platforms

type Platform struct {
	Name    string
	Version string
}

// Dependency

//type Dependency struct {
//	Identity string
//	Type     string
//	URL      string
//	//Requirements []Requirement
//}
