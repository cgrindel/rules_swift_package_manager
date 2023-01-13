package swiftpkg

import (
	"fmt"
)

// GH010: Add test for ExportedTargets

// ExportedTargets returns targets that are made available outside of the package via a Product
// reference.
func (pi *PackageInfo) ExportedTargets() ([]*Target, error) {
	exported := make([]*Target, len(pi.Products))
	for idx, p := range pi.Products {
		if len(p.Targets) == 0 {
			return nil, fmt.Errorf("product %s has no targets", p.Name)
		}
		targetName := p.Targets[0]
		t := pi.Targets.FindByName(targetName)
		if t == nil {
			return nil, fmt.Errorf(
				"target %s not found while generating exported targets", targetName)
		}
		exported[idx] = t
	}
	return exported, nil
}
