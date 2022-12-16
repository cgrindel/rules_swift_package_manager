package spdump

import (
	"encoding/json"
	"fmt"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonutils"
)

type TargetDependency struct {
	Product *ProductReference
	ByName  *ByNameReference
	Target  *TargetReference
}

func (td *TargetDependency) ImportName() string {
	if td.Product != nil {
		return td.Product.ProductName
	} else if td.ByName != nil {
		return td.ByName.TargetName
	}
	return ""
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

func (pr *ProductReference) UniqKey() string {
	return fmt.Sprintf("%s-%s", pr.DependencyName, pr.ProductName)
}

// ByNameReference

// Reference a target by name
type ByNameReference struct {
	// TODO(chuck): Should this be Name? Can it refer to a target or a product?
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

// TargetReference

// Reference a target by name
type TargetReference struct {
	TargetName string
}

func (tr *TargetReference) UnmarshalJSON(b []byte) error {
	var err error
	var raw []any
	if err := json.Unmarshal(b, &raw); err != nil {
		return err
	}
	if tr.TargetName, err = jsonutils.StringAtIndex(raw, 0); err != nil {
		return err
	}
	return nil
}
