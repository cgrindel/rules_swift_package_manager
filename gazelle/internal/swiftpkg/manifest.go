package swiftpkg

import (
	"encoding/json"
	"log"
	"strings"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonutils"
	multierror "github.com/hashicorp/go-multierror"
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
	Products     []Product
	Targets      []Target
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
	var errs error

	var raw map[string]any
	err := json.Unmarshal(b, &raw)
	if err != nil {
		return err
	}

	srcCtrlList, err := jsonutils.SliceAtKey(raw, "sourceControl")
	if err != nil {
		return err
	}
	if len(srcCtrlList) == 0 {
		log.Println(dependencyLogPrefix, "Expected at least one entry in `sourceControl` list.")
		return nil
	}
	srcCtrlEntry := srcCtrlList[0].(map[string]any)

	// Name
	if d.Name, err = jsonutils.StringAtKey(srcCtrlEntry, "identity"); err != nil {
		errs = multierror.Append(errs, err)
	}

	// URL
	if location, err := jsonutils.MapAtKey(srcCtrlEntry, "location"); err == nil {
		if remotes, err := jsonutils.SliceAtKey(location, "remote"); err == nil {
			if len(remotes) > 0 {
				d.URL = remotes[0].(string)
			}
		} else {
			errs = multierror.Append(errs, err)
		}
	} else {
		errs = multierror.Append(errs, err)
	}

	// Requirement
	if err = jsonutils.UnmarshalAtKey(srcCtrlEntry, "requirement", &d.Requirement); err != nil {
		errs = multierror.Append(errs, err)
	}

	return errs
}

// Platform

type Platform struct {
	Name    string `json:"platformName"`
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

type Product struct {
	Name    string
	Targets []string
	Type    ProductType
}

func (p *Product) UnmarshalJSON(b []byte) error {
	var errs error

	var raw map[string]any
	err := json.Unmarshal(b, &raw)
	if err != nil {
		return err
	}
	if p.Name, err = jsonutils.StringAtKey(raw, "name"); err != nil {
		errs = multierror.Append(errs, err)
	}
	if p.Targets, err = jsonutils.StringsAtKey(raw, "targets"); err != nil {
		errs = multierror.Append(errs, err)
	}
	if typeMap, err := jsonutils.MapAtKey(raw, "type"); err == nil {
		if _, present := typeMap["executable"]; present {
			p.Type = ExecutableProductType
		} else if _, present = typeMap["library"]; present {
			p.Type = LibraryProductType
		} else if _, present = typeMap["plugin"]; present {
			p.Type = PluginProductType
		}
	} else {
		errs = multierror.Append(errs, err)
	}
	return errs
}

// Target

type TargetType int

const (
	UnknownTargetType TargetType = iota
	ExecutableTargetType
	LibraryTargetType
	TestTargetType
)

func (tt *TargetType) UnmarshalJSON(b []byte) error {
	// The bytes are a raw string (i.e., includes double quotes at front and back). Remove them.
	ttStr := strings.Trim(string(b), "\"")
	switch ttStr {
	case "executable":
		*tt = ExecutableTargetType
	case "test":
		*tt = TestTargetType
	case "library":
		*tt = LibraryTargetType
	default:
		*tt = UnknownTargetType
	}
	return nil
}

type Target struct {
	Name         string
	Type         TargetType
	Dependencies []TargetDependency
}

// TargetDependenncy

type TargetDependency struct {
	Product *ProductReference
	ByName  *ByNameReference
}

// ProductReference

// Reference a product
type ProductReference struct {
	ProductName    string
	DependencyName string
}

func (pr *ProductReference) UnmarshalJSON(b []byte) error {
	var err error
	var raw []any
	if err := json.Unmarshal(b, &raw); err != nil {
		return err
	}
	if pr.ProductName, err = jsonutils.StringAtIndex(raw, 0); err != nil {
		return err
	}
	if pr.DependencyName, err = jsonutils.StringAtIndex(raw, 1); err != nil {
		return err
	}
	return nil
}

// ByNameReference

// Reference a target by name
type ByNameReference struct {
	TargetName string
}

func (bnr *ByNameReference) UnmarshalJSON(b []byte) error {
	var err error
	var raw []any
	if err := json.Unmarshal(b, &raw); err != nil {
		return err
	}
	if bnr.TargetName, err = jsonutils.StringAtIndex(raw, 0); err != nil {
		return err
	}
	return nil
}
