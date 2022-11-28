package spdump

import (
	"encoding/json"
	"sort"
)

// The JSON formats described in this file are for the swift package dump-package JSON output.

func NewManifestFromJSON(bytes []byte) (*Manifest, error) {
	var manifest Manifest
	err := json.Unmarshal(bytes, &manifest)
	if err != nil {
		return nil, err
	}
	return &manifest, nil
}

// Manifest

type Manifest struct {
	Name         string
	Dependencies []Dependency
	Platforms    []Platform
	Products     []Product
	Targets      []Target
}

// Returns a uniq slice of the product references used in the manifest
func (m *Manifest) ProductReferences() []*ProductReference {
	prs := make(map[string]*ProductReference)

	addProdRef := func(pr *ProductReference) {
		if pr == nil {
			return
		}
		uk := pr.UniqKey()
		if _, ok := prs[uk]; !ok {
			prs[uk] = pr
		}
	}

	for _, t := range m.Targets {
		for _, td := range t.Dependencies {
			addProdRef(td.Product)
		}
	}

	keys := make([]string, 0, len(prs))
	for k := range prs {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	result := make([]*ProductReference, 0, len(prs))
	for _, k := range keys {
		result = append(result, prs[k])
	}
	return result
}
