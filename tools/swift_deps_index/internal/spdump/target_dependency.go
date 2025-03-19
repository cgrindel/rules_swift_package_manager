package spdump

import (
	"encoding/json"
	"fmt"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/jsonutils"
)

// A TargetDependency represents a reference to a target's dependency.
type TargetDependency struct {
	Product *ProductReference
	ByName  *ByNameReference
	Target  *TargetReference
}

// GH148: Confirm whether targets that depend upon a library product import the product name or one
// of the modules referenced by the product.

// ImportName returns the name used to import the dependency.
func (td *TargetDependency) ImportName() string {
	if td.Product != nil {
		return td.Product.ProductName
	} else if td.ByName != nil {
		return td.ByName.Name
	}
	return ""
}

// ProductReference

// A ProductReference encapsulates a reference to a Swift product.
type ProductReference struct {
	ProductName    string
	DependencyName string
}

func (pr *ProductReference) UnmarshalJSON(b []byte) error {
	var err error
	var raw []any
	if err = json.Unmarshal(b, &raw); err != nil {
		return err
	}
	if pr.ProductName, err = jsonutils.StringAtIndex(raw, 0); err != nil {
		return err
	}
	if pr.DependencyName, err = jsonutils.StringAtIndex(raw, 1); err != nil {
		// Per SPM code, a single name implies that the product,
		// package, and target all have the same name.
		pr.DependencyName = pr.ProductName
	}
	return nil
}

// UniqKey returns a string that can be used as a map key for the product.
func (pr *ProductReference) UniqKey() string {
	return fmt.Sprintf("%s-%s", pr.DependencyName, pr.ProductName)
}

// ByNameReference

// A ByNameReference represents a byName reference. It can be a product name or a target name.
type ByNameReference struct {
	// Product name or target name
	Name string
}

func (bnr *ByNameReference) UnmarshalJSON(b []byte) error {
	var err error
	var raw []any
	if err = json.Unmarshal(b, &raw); err != nil {
		return err
	}
	if bnr.Name, err = jsonutils.StringAtIndex(raw, 0); err != nil {
		return err
	}
	return nil
}

// TargetReference

// A TargetReference represents a reference to a Swift target.
type TargetReference struct {
	TargetName string
}

func (tr *TargetReference) UnmarshalJSON(b []byte) error {
	var err error
	var raw []any
	if err = json.Unmarshal(b, &raw); err != nil {
		return err
	}
	if tr.TargetName, err = jsonutils.StringAtIndex(raw, 0); err != nil {
		return err
	}
	return nil
}
