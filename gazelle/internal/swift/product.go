package swift

import (
	"encoding/json"
	"fmt"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

type productJSONData struct {
	Identity     string    `json:"identity"`
	Name         string    `json:"name"`
	Type         string    `json:"type"`
	TargetLabels LabelStrs `json:"target_labels"`
}

// A ProductType is an enum for a Swift product type.
type ProductType int

const (
	UnknownProductType = iota
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
	Identity     string
	Name         string
	Type         ProductType
	TargetLabels []*label.Label
}

func NewProduct(identity, name string, ptype ProductType, targetLabels []*label.Label) *Product {
	return &Product{
		Identity:     identity,
		Name:         name,
		Type:         ptype,
		TargetLabels: targetLabels,
	}
}

// NewProductFromPkgInfoProduct returns a Swift product based upon a Swift manifest product.
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
	targetLabels := make([]*label.Label, len(prd.Targets))
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

	targetLabels := make(LabelStrs, len(p.TargetLabels))
	for idx, tl := range p.TargetLabels {
		targetLabels[idx] = NewLabelStr(tl)
	}

	return &productJSONData{
		Identity:     p.Identity,
		Name:         p.Name,
		Type:         ptype,
		TargetLabels: targetLabels,
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

	targetLabels := make([]*label.Label, len(jd.TargetLabels))
	for idx, tl := range jd.TargetLabels {
		targetLabels[idx], err = NewLabel(tl)
		if err != nil {
			return nil, err
		}
	}

	return NewProduct(jd.Identity, jd.Name, ptype, targetLabels), nil
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
