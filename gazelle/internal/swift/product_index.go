package swift

import "fmt"

// ProductIndexKey

type ProductIndexKey string

func NewProductIndexKey(identity, name string) ProductIndexKey {
	return ProductIndexKey(fmt.Sprintf("%s|%s", identity, name))
}

func NewProductIndexKeyFromProduct(p *Product) ProductIndexKey {
	return NewProductIndexKey(p.Identity, p.Name)
}

// ProductIndex

type ProductIndex map[ProductIndexKey]*Product

// func (pi ProductIndex) Add(p *Product) {
// 	key := NewProductIndexKeyFromProduct(p)
// 	pi[key] = p
// }

func (pi ProductIndex) Add(products ...*Product) {
	for _, p := range products {
		key := NewProductIndexKeyFromProduct(p)
		pi[key] = p
	}
}

func (pi ProductIndex) Resolve(identity, name string) *Product {
	key := NewProductIndexKey(identity, name)
	return pi[key]
}
