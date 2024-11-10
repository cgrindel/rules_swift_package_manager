package swiftpkg

import (
	"fmt"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spdump"
)

type ProductType struct {
	Executable   bool              `json:"executable"`
	IsExecutable bool              `json:"is_executable"`
	IsLibrary    bool              `json:"is_library"`
	IsMacro      bool              `json:"is_macro"`
	IsPlugin     bool              `json:"is_plugin"`
	Library      map[string]string `json:"library"`
}

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
	case spdump.ExecutableProductType:
		prdType.Executable = true
		prdType.IsExecutable = true
	case spdump.LibraryProductType:
		prdType.IsLibrary = true
		prdType.Library = map[string]string{
			"kind": "automatic",
		}
	case spdump.PluginProductType:
		prdType.IsPlugin = true
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
