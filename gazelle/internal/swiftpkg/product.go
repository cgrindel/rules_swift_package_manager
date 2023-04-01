package swiftpkg

import (
	"fmt"

	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/spdump"
)

// A ProductType is an enum for the type of Swift product.
type ProductType int

const (
	UnknownProductType ProductType = iota
	ExecutableProductType
	LibraryProductType
	PluginProductType
)

// A Product represents a Swift product.
type Product struct {
	Name    string
	Targets []string
	Type    ProductType
}

// NewProductFromManifestInfo returns a Swift product from manifest information.
func NewProductFromManifestInfo(dumpP *spdump.Product) (*Product, error) {
	var prdType ProductType
	switch dumpP.Type {
	case spdump.UnknownProductType:
		prdType = UnknownProductType
	case spdump.ExecutableProductType:
		prdType = ExecutableProductType
	case spdump.LibraryProductType:
		prdType = LibraryProductType
	case spdump.PluginProductType:
		prdType = PluginProductType
	default:
		return nil, fmt.Errorf(
			"unrecognized product type %v for %s product", dumpP.Type, dumpP.Name)
	}
	return &Product{
		Name:    dumpP.Name,
		Targets: dumpP.Targets,
		Type:    prdType,
	}, nil
}
