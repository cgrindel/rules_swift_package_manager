package swiftpkg

import (
	"fmt"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
)

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
