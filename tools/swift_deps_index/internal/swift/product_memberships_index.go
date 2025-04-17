package swift

import (
	mapset "github.com/deckarep/golang-set/v2"
)

type ProductMembershipsIndex map[ProductIndexKey]mapset.Set[string]

func (pmi ProductMembershipsIndex) Add(prdIndexKey ProductIndexKey, moduleNames ...string) {
	modNamesSet, ok := pmi[prdIndexKey]
	if !ok {
		modNamesSet = mapset.NewSet[string]()
	}
	for _, mname := range moduleNames {
		modNamesSet.Add(mname)
	}
	pmi[prdIndexKey] = modNamesSet
}

func (pmi ProductMembershipsIndex) IndexModule(m *Module) {
	for _, prdName := range m.ProductMemberships {
		prdIdxKey := NewProductIndexKey(m.PkgIdentity, prdName)
		pmi.Add(prdIdxKey, m.Name)
		if m.Name != m.C99name {
			pmi.Add(prdIdxKey, m.C99name)
		}
	}
}
