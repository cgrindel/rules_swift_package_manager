package spdump

import "encoding/json"

// A ProductType is an enum for identifying the type of Swift product.
type ProductType int

const (
	UnknownProductType ProductType = iota
	ExecutableProductType
	LibraryProductType
	PluginProductType
)

func (pt *ProductType) UnmarshalJSON(b []byte) error {
	var anyMap map[string]any
	err := json.Unmarshal(b, &anyMap)
	if err != nil {
		return err
	}
	if _, ok := anyMap["executable"]; ok {
		*pt = ExecutableProductType
	} else if _, ok = anyMap["library"]; ok {
		*pt = LibraryProductType
	} else if _, ok = anyMap["plugin"]; ok {
		*pt = PluginProductType
	}
	return nil
}

// A Product represents a Swift product.
type Product struct {
	Name    string
	Targets []string
	Type    ProductType
}
