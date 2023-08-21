package swift

import "golang.org/x/exp/slices"

type PackageIndex map[string]*Package

func NewPackageIndex(packages ...*Package) PackageIndex {
	pi := make(PackageIndex)
	pi.Add(packages...)
	return pi
}

func (pi PackageIndex) Add(packages ...*Package) {
	for _, p := range packages {
		pi[p.Identity] = p
	}
}

func (pi PackageIndex) Packages() []*Package {
	results := make([]*Package, 0, len(pi))
	for _, p := range pi {
		results = append(results, p)
	}
	cmpFn := func(a, b *Package) int {
		if a.Name < b.Name {
			return -1
		}
		if a.Name == b.Name {
			return 0
		}
		return 1
	}
	slices.SortFunc(results, cmpFn)
	return results
}
