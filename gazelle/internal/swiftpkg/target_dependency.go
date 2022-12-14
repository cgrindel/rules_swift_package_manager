package swiftpkg

import (
	"fmt"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
)

type TargetDependency struct {
	Product *ProductReference
	ByName  *ByNameReference
}

func NewTargetDependencyFromManifestInfo(dumpTD *spdump.TargetDependency) (*TargetDependency, error) {
	var prodRef *ProductReference
	var byNameRef *ByNameReference
	if dumpTD.Product != nil {
		prodRef = NewProductReferenceFromManifestInfo(dumpTD.Product)
	} else if dumpTD.ByName != nil {
		byNameRef = NewByNameReferenceFromManifestInfo(dumpTD.ByName)
	} else {
		return nil, fmt.Errorf("invalid target dependency")
	}
	return &TargetDependency{
		Product: prodRef,
		ByName:  byNameRef,
	}, nil
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
	// Product name
	ProductName string
	// External dependency identity
	Identity string
}

func NewProductReferenceFromManifestInfo(dumpPR *spdump.ProductReference) *ProductReference {
	return &ProductReference{
		ProductName: dumpPR.ProductName,
		Identity:    dumpPR.DependencyName,
	}
}

func (pr *ProductReference) UniqKey() string {
	return fmt.Sprintf("%s-%s", pr.Identity, pr.ProductName)
}

// ByNameReference

// Reference a target by name
type ByNameReference struct {
	TargetName string
}

func NewByNameReferenceFromManifestInfo(dumpBNR *spdump.ByNameReference) *ByNameReference {
	return &ByNameReference{
		TargetName: dumpBNR.TargetName,
	}
}
