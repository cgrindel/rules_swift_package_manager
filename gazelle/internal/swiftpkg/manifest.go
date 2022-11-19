package swiftpkg

import (
	"encoding/json"
	"log"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonmap"
)

// The JSON formats described in this file are for the swift package dump-package JSON output.

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
	Name         string
	Dependencies []Dependency
	Platforms    []Platform
	// Products     []Product
	// Targets      []Target
}

// Dependency

type Dependency struct {
	Name        string
	URL         string
	Requirement DependencyRequirement
}

type DependencyRequirement struct {
	Range []VersionRange
}

type VersionRange struct {
	LowerBound string
	UpperBound string
}

const dependencyLogPrefix = "Decoding Dependency:"

func (d *Dependency) UnmarshalJSON(b []byte) error {
	var raw map[string]any
	err := json.Unmarshal(b, &raw)
	if err != nil {
		return err
	}

	srcCtrlList, ok := jsonmap.Slice(raw, "sourceControl")
	if !ok {
		log.Println(dependencyLogPrefix, "Expected to find `sourceControl`.")
		return nil
	}
	if len(srcCtrlList) == 0 {
		log.Println(dependencyLogPrefix, "Expected at least one entry in `sourceControl` list.")
		return nil
	}
	srcCtrlEntry := srcCtrlList[0].(map[string]any)

	// Name
	if d.Name, ok = jsonmap.String(srcCtrlEntry, "identity"); !ok {
		log.Println(dependencyLogPrefix, "Expected `identity` in source control entry.")
	}

	// URL
	if location, ok := jsonmap.Map(srcCtrlEntry, "location"); ok {
		if remotes, ok := jsonmap.Slice(location, "remote"); ok {
			if len(remotes) > 0 {
				d.URL = remotes[0].(string)
			}
		}
	} else {
		log.Println(dependencyLogPrefix, "Expected `location` in source control entry.")
	}

	// Requirement
	if ok := jsonmap.Unmarshal(srcCtrlEntry, "requirement", &d.Requirement); !ok {
		log.Println(dependencyLogPrefix, "Expected `requirement` in source control entry.")
	}

	return nil
}

// Platform

type Platform struct {
	Name    string `json:"platformName"`
	Version string
}


