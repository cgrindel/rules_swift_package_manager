package swift

// A ModuleToProductsIndex maps a module name to the products to which it belongs (i.e., has
// membership).
type ModuleToProductsIndex map[string][]ProductIndexKey

func (mpi ModuleToProductsIndex) Add(moduleName string, newKeys ...ProductIndexKey) {
	prdIdxKeys := mpi[moduleName]
	prdIdxKeys = append(prdIdxKeys, newKeys...)
	mpi[moduleName] = prdIdxKeys
}

func (mpi ModuleToProductsIndex) IndexModule(m *Module) {
	for _, prdName := range m.ProductMemberships {
		prdIdxKey := NewProductIndexKey(m.PkgIdentity, prdName)
		mpi.Add(m.Name, prdIdxKey)
		if m.Name != m.C99name {
			mpi.Add(m.C99name, prdIdxKey)
		}
	}
}
