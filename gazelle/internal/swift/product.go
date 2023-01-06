package swift

import (
	"fmt"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

type ProductType int

const (
	UnknownProductType = iota
	LibraryProductType
	ExecutableProductType
	PluginProductType
)

// A Swift package product can
type Product struct {
	Identity     string
	Name         string
	Type         ProductType
	TargetLabels []label.Label
}

func NewProduct(identity, name string, ptype ProductType, targetLabels []label.Label) *Product {
	return &Product{
		Identity:     identity,
		Name:         name,
		Type:         ptype,
		TargetLabels: targetLabels,
	}
}

func NewProductFromPkgInfoProduct(
	bzlRepo *BazelRepo,
	prd *swiftpkg.Product,
) (*Product, error) {
	var ptype ProductType
	switch prd.Type {
	case swiftpkg.ExecutableProductType:
		ptype = ExecutableProductType
	case swiftpkg.LibraryProductType:
		ptype = LibraryProductType
	case swiftpkg.PluginProductType:
		ptype = PluginProductType
	default:
		ptype = UnknownProductType
	}

	pi := bzlRepo.PkgInfo
	targetLabels := make([]label.Label, len(prd.Targets))
	for idx, tname := range prd.Targets {
		t := pi.Targets.FindByName(tname)
		if t == nil {
			return nil, fmt.Errorf(
				"did not find target %v for product %v in repo %v",
				tname, prd.Name, bzlRepo.Identity)
		}
		targetLabels[idx] = BazelLabelFromTarget(bzlRepo.Name, t)
	}

	return NewProduct(bzlRepo.Identity, prd.Name, ptype, targetLabels), nil
}
