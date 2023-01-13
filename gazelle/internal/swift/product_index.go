package swift

import (
	"encoding/json"
	"fmt"
	"sort"
)

// ProductIndexKey

// A ProductIndexKey represents the key used to index products.
type ProductIndexKey string

func NewProductIndexKey(identity, name string) ProductIndexKey {
	return ProductIndexKey(fmt.Sprintf("%s|%s", identity, name))
}

// ProductIndex

// A ProductIndex represents products organized by a unique key.
type ProductIndex map[ProductIndexKey]*Product

// Add indexes the provided products.
func (pi ProductIndex) Add(products ...*Product) {
	for _, p := range products {
		pi[p.IndexKey()] = p
	}
}

// Resolve finds the product based upon identity and product name.
func (pi ProductIndex) Resolve(identity, name string) *Product {
	key := NewProductIndexKey(identity, name)
	return pi[key]
}

// Products returns the products in the index.
func (pi ProductIndex) Products() []*Product {
	keys := make([]string, len(pi))
	idx := 0
	for k := range pi {
		keys[idx] = string(k)
		idx++
	}
	sort.Strings(keys)
	result := make([]*Product, len(keys))
	for idx, k := range keys {
		result[idx] = pi[ProductIndexKey(k)]
	}
	return result
}

func (pi ProductIndex) MarshalJSON() ([]byte, error) {
	return json.Marshal(pi.Products())
}

func (pi *ProductIndex) UnmarshalJSON(b []byte) error {
	var products []*Product
	if err := json.Unmarshal(b, &products); err != nil {
		return err
	}
	newpi := make(ProductIndex)
	newpi.Add(products...)
	*pi = newpi
	return nil
}
