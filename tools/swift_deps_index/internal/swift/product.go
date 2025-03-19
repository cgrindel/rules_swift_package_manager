package swift

import (
	"encoding/json"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	mapset "github.com/deckarep/golang-set/v2"
)

type productJSONData struct {
	Identity string   `json:"identity"`
	Name     string   `json:"name"`
	Type     string   `json:"type"`
	Label    LabelStr `json:"label"`
}

// A ProductType is an enum for a Swift product type.
type ProductType int

const (
	UnknownProductType ProductType = iota
	LibraryProductType
	ExecutableProductType
	PluginProductType
)

const (
	UnknownProductTypeStr    = "unknown"
	LibraryProductTypeStr    = "library"
	ExecutableProductTypeStr = "executable"
	PluginProductTypeStr     = "plugin"
)

// A Product represents a Swift package product.
type Product struct {
	Identity string
	Name     string
	Type     ProductType
	Label    *label.Label
}

func NewProduct(identity, name string, ptype ProductType, label *label.Label) *Product {
	return &Product{
		Identity: identity,
		Name:     name,
		Type:     ptype,
		Label:    label,
	}
}

// NewProductFromPkgInfoProduct returns a Swift product based upon a Swift manifest product.
func NewProductFromPkgInfoProduct(
	bzlRepo *BazelRepo,
	prd *swiftpkg.Product,
) (*Product, error) {
	var ptype ProductType
	if prd.Type.IsExecutable {
		ptype = ExecutableProductType
	} else if prd.Type.IsLibrary {
		ptype = LibraryProductType
	} else if prd.Type.IsPlugin {
		ptype = PluginProductType
	} else {
		ptype = UnknownProductType
	}

	label := label.New(bzlRepo.Name, "", prd.Name)

	return NewProduct(bzlRepo.Identity, prd.Name, ptype, &label), nil
}

// IndexKey returns a unique key for the product.
func (p *Product) IndexKey() ProductIndexKey {
	return NewProductIndexKey(p.Identity, p.Name)
}

// JSON Output

func (p *Product) jsonData() *productJSONData {
	var ptype string
	switch p.Type {
	case LibraryProductType:
		ptype = LibraryProductTypeStr
	case ExecutableProductType:
		ptype = ExecutableProductTypeStr
	case PluginProductType:
		ptype = PluginProductTypeStr
	default:
		ptype = UnknownProductTypeStr
	}

	return &productJSONData{
		Identity: p.Identity,
		Name:     p.Name,
		Type:     ptype,
		Label:    NewLabelStr(p.Label),
	}
}

func newProductFromJSONData(jd *productJSONData) (*Product, error) {
	var err error

	var ptype ProductType
	switch jd.Type {
	case LibraryProductTypeStr:
		ptype = LibraryProductType
	case ExecutableProductTypeStr:
		ptype = ExecutableProductType
	case PluginProductTypeStr:
		ptype = PluginProductType
	default:
		ptype = UnknownProductType
	}

	plabel, err := NewLabel(jd.Label)
	if err != nil {
		return nil, err
	}

	return NewProduct(jd.Identity, jd.Name, ptype, plabel), nil
}

func (p *Product) MarshalJSON() ([]byte, error) {
	return json.Marshal(p.jsonData())
}

func (p *Product) UnmarshalJSON(b []byte) error {
	var err error
	var jd productJSONData
	if err = json.Unmarshal(b, &jd); err != nil {
		return err
	}
	newp, err := newProductFromJSONData(&jd)
	*p = *newp
	return err
}

// Products

type Products []*Product

func (prds Products) Labels() mapset.Set[*label.Label] {
	labels := mapset.NewSet[*label.Label]()
	for _, p := range prds {
		labels.Add(p.Label)
	}
	return labels
}
