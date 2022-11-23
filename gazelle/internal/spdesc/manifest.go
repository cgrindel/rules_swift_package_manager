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

type Manifest struct {
	Name                string
	ManifestDisplayName string `json:"manifest_display_name"`
	Path                string
	// Platforms          []Platform
	// Products           []Product
	// Targets            []Target
}
