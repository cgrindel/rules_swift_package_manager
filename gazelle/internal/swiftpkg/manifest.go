package swiftpkg

import (
	"encoding/json"
	"log"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonutils"
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
	var raw map[string]any
	err := json.Unmarshal(b, &raw)
	if err != nil {
		return err
	}

	srcCtrlList, ok := jsonutils.Slice(raw, "sourceControl")
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
	if d.Name, ok = jsonutils.String(srcCtrlEntry, "identity"); !ok {
		log.Println(dependencyLogPrefix, "Expected `identity` in source control entry.")
	}

	// URL
	if location, ok := jsonutils.Map(srcCtrlEntry, "location"); ok {
		if remotes, ok := jsonutils.Slice(location, "remote"); ok {
			if len(remotes) > 0 {
				d.URL = remotes[0].(string)
			}
		}
	} else {
		log.Println(dependencyLogPrefix, "Expected `location` in source control entry.")
	}

	// Requirement
	if ok := jsonutils.Unmarshal(srcCtrlEntry, "requirement", &d.Requirement); !ok {
		log.Println(dependencyLogPrefix, "Expected `requirement` in source control entry.")
	}

	return nil
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
	var ok bool
	var raw map[string]any
	err := json.Unmarshal(b, &raw)
	if err != nil {
		return err
	}
	if p.Name, ok = jsonutils.String(raw, "name"); !ok {
		log.Println(dependencyLogPrefix, "Expected `name` in product.")
	}
	if p.Targets, ok = jsonutils.Strings(raw, "targets"); !ok {
		log.Println(dependencyLogPrefix, "Expected `targets` in product.")
	}
	if typeMap, ok := jsonutils.Map(raw, "type"); ok {
		if _, present := typeMap["executable"]; present {
			p.Type = ExecutableProductType
		} else if _, present = typeMap["library"]; present {
			p.Type = LibraryProductType
		} else if _, present = typeMap["plugin"]; present {
			p.Type = PluginProductType
		}
	} else {
		log.Println(dependencyLogPrefix, "Expected `type` in product.")
	}
	return nil
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
// 	if rawProduct, ok := jsonutils.Slice(raw, "product"); ok {
// 		td.Type = ProductTargetDependencyType
// 		td.Product, err = newProductReferenceFromAnySlice(rawProduct)
// 		if err != nil {
// 			return err
// 		}
// 		// } else if rawByName, ok := jsonutils.Slice(raw, "byName"); ok {
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
