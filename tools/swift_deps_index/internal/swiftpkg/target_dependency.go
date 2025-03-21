package swiftpkg

import (
	"fmt"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spdump"
)

// A TargetDependency represents a Swift target dependency.
type TargetDependency struct {
	Product *ProductReference
	ByName  *ByNameReference
	Target  *TargetReference
}

// NewTargetDependencyFromManifestInfo returns a target dependency from manifest information.
func NewTargetDependencyFromManifestInfo(dumpTD *spdump.TargetDependency) (*TargetDependency, error) {
	var prodRef *ProductReference
	var byNameRef *ByNameReference
	var targetRef *TargetReference
	if dumpTD.Product != nil {
		prodRef = NewProductReferenceFromManifestInfo(dumpTD.Product)
	} else if dumpTD.ByName != nil {
		byNameRef = NewByNameReferenceFromManifestInfo(dumpTD.ByName)
	} else if dumpTD.Target != nil {
		targetRef = NewTargetReferenceFromManifestInfo(dumpTD.Target)
	} else {
		return nil, fmt.Errorf("invalid target dependency")
	}
	return &TargetDependency{
		Product: prodRef,
		ByName:  byNameRef,
		Target:  targetRef,
	}, nil
}

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

// A ProductReference represents a reference to a product.
type ProductReference struct {
	// Product name
	ProductName string
	// External dependency identity
	Identity string
}

// NewProductReferenceFromManifestInfo returns a product reference from manifest information.
func NewProductReferenceFromManifestInfo(dumpPR *spdump.ProductReference) *ProductReference {
	return &ProductReference{
		ProductName: dumpPR.ProductName,
		Identity:    dumpPR.DependencyName,
	}
}

// UniqKey returns the value used to lookup a Swift product from a reference.
func (pr *ProductReference) UniqKey() string {
	return fmt.Sprintf("%s-%s", pr.Identity, pr.ProductName)
}

// ByNameReference

// A ByNameReference references a product or target by name.
type ByNameReference struct {
	// Product name or target name
	Name string
}

// NewByNameReferenceFromManifestInfo returns a by-name reference from manifest information.
func NewByNameReferenceFromManifestInfo(dumpBNR *spdump.ByNameReference) *ByNameReference {
	return &ByNameReference{
		Name: dumpBNR.Name,
	}
}

// TargetReference

// TargetReference references a target by name.
type TargetReference struct {
	TargetName string
}

// NewTargetReferenceFromManifestInfo returns a target reference from manifest information.
func NewTargetReferenceFromManifestInfo(dumpTR *spdump.TargetReference) *TargetReference {
	return &TargetReference{
		TargetName: dumpTR.TargetName,
	}
}
