package swiftpkg

import (
	"fmt"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdesc"
)

// Targets that are made available outside of the package via a Product reference.
func (pi *PackageInfo) ExportedTargets() ([]*spdesc.Target, error) {
	m := pi.DescManifest

	exported := make([]*spdesc.Target, len(m.Products))
	for idx, p := range m.Products {
		if len(p.Targets) == 0 {
			return nil, fmt.Errorf("product %s has not targets", p.Name)
		}
		targetName := p.Targets[0]
		t := m.Targets.FindByName(targetName)
		if t == nil {
			return nil, fmt.Errorf("target %s not found while finding product module", targetName)
		}
		exported[idx] = t
	}
	return exported, nil
}
