package swift

import (
	"fmt"
	"sort"
	"strings"
)

// ProductIndexKey

// A ProductIndexKey represents the key used to index products.
type ProductIndexKey string

// NewProductIndexKey creates a product index key from a package identity and product name.
func NewProductIndexKey(identity, name string) ProductIndexKey {
	return ProductIndexKey(fmt.Sprintf("%s|%s", identity, name))
}

func (pik ProductIndexKey) Identity() string {
	parts := strings.Split(string(pik), "|")
	return parts[0]
}

// ProductIndexKeys

type ProductIndexKeys []ProductIndexKey

func (piks ProductIndexKeys) Len() int {
	return len(piks)
}

func (piks ProductIndexKeys) Less(i, j int) bool {
	return piks[i] < piks[j]
}

func (piks ProductIndexKeys) Swap(i, j int) {
	piks[i], piks[j] = piks[j], piks[i]
}

// ProductIndex

// A ProductIndex represents products organized by a unique key.
type ProductIndex map[ProductIndexKey]*Product

// NewProductIndex creates a product index populated with the provided products.
func NewProductIndex(products ...*Product) ProductIndex {
	pi := make(ProductIndex)
	pi.Add(products...)
	return pi
}

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
