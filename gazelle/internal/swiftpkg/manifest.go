package swiftpkg

import (
	"encoding/json"
	"log"

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

	var ok bool
	var raw map[string]any
	err := json.Unmarshal(b, &raw)
	if err != nil {
		return err
	}
	if p.Name, err = jsonutils.StringAtKey(raw, "name"); err != nil {
		errs = multierror.Append(errs, err)
	}
	if p.Targets, ok = jsonutils.StringsAtKey(raw, "targets"); !ok {
		log.Printf("over zealous edit")
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

// // Target
//
// type TargetType int
//
// const (
// 	UnknownTargetType TargetType = iota
// 	ExecutableTargetType
// 	LibraryTargetType
// 	TestTargetType
// )
//
// type Target struct {
// 	Name         string
// 	Type         TargetType
// 	Dependencies []TargetDependency
// }
//
// type TargetDependencyType int
//
// const (
// 	UnknownTargetDependencyType TargetDependencyType = iota
// 	ProductTargetDependencyType
// 	ByNameTargetDependencyType
// )
//
// // type TargetDependency interface {
// // 	TargetDependencyType() TargetDependencyType
// // }
//
// type TargetDependency struct {
// 	Type    TargetDependencyType
// 	Product ProductReference
// 	ByName  ByNameReference
// }
//
// func (td *TargetDependency) UnmarshalJSON(b []byte) error {
// 	var raw map[string]any
// 	err := json.Unmarshal(b, &raw)
// 	if err != nil {
// 		return err
// 	}
//
// 	if rawProduct, ok := jsonutils.SliceAtKey(raw, "product"); ok {
// 		td.Type = ProductTargetDependencyType
// 		td.Product, err = newProductReferenceFromAnySlice(rawProduct)
// 		if err != nil {
// 			return err
// 		}
// 		// } else if rawByName, ok := jsonutils.SliceAtKey(raw, "byName"); ok {
// 		// 	td.Type = ByNameTargetDependencyType
// 		// 	td.ByName, err = newByNameReferenceFromAnySlice(rawByName)
// 		// 	if err != nil {
// 		// 		return err
// 		// 	}
// 	} else {
// 		return fmt.Errorf("unrecognized target dependency")
// 	}
// 	return nil
// }
//
// // Reference a product
// type ProductReference struct {
// 	ProductName    string
// 	DependencyName string
// }
//
// func newProductReferenceFromAnySlice(anyValues []any) (ProductReference, error) {
// 	var pr ProductReference
// 	// Product reference slices usually have 4 values.
// 	// 0: ProductName
// 	// 1: DependencyName
// 	// 2: null
// 	// 3: null
// 	if len(anyValues) < 2 {
// 		return pr, fmt.Errorf("expected at least two values from any slice for ProduceReference")
// 	}
// 	// TODO(chuck): FIX ME!
// 	// DEBUG BEGIN
// 	log.Printf("*** CHUCK newProductReferenceFromAnySlice anyValues: ")
// 	for idx, item := range anyValues {
// 		log.Printf("*** CHUCK %d: %+#v", idx, item)
// 	}
// 	// DEBUG END
// 	return pr, nil
// }
//
// // Reference a target by name
// type ByNameReference struct {
// 	TargetName string
// }
//
// // func newByNameReferenceFromAnySlice(anyValues []any) (ByNameReference, error) {
// // 	var bnr ByNameReference
// // 	if len(anyValues) < 1 {
// // 		return bnr, fmt.Errorf("expected at least one value from any slice for ByNameReference")
// // 	}
// // 	v := anyValues[0]
// // 	switch t := value {
// // 	case value1:
//
// // 	case value2:
//
// // 	default:
//
// // 	}
//
// // 	bnr.TargetName = ""
// // 	return bnr, nil
// // }
