package reslog

import (
	"sort"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"golang.org/x/exp/slices"
)

type RuleResolutionSummary struct {
	Name           string                    `yaml:"name"`
	Kind           string                    `yaml:"kind"`
	Imports        []string                  `yaml:"imports"`
	Builtins       []string                  `yaml:"builtins,omitempty"`
	LocalRes       []ModuleLabel             `yaml:"local_resolution,omitempty"`
	ExtRes         ExternalResolutionSummary `yaml:"external_resolution,omitempty"`
	HTTPArchiveRes []ModuleLabel             `yaml:"http_archive_resolution,omitempty"`
	Unresolved     []string                  `yaml:"unresolved,omitempty"`
	Deps           []string                  `yaml:"deps"`
}

type ModuleLabel struct {
	Module string
	Label  string
}

func moduleLabelCompare(a, b ModuleLabel) int {
	if a.Module < b.Module {
		return -1
	}
	if a.Module == b.Module {
		return 0
	}
	return 1
}

type Product struct {
	Identity string
	Name     string
	Label    string
}

func newProductFromSwiftProduct(p *swift.Product) Product {
	prd := Product{
		Identity: p.Identity,
		Name:     p.Name,
		Label:    p.Label.String(),
	}
	return prd
}

type ExternalResolutionSummary struct {
	Modules    []string
	Products   []Product
	Unresolved []string
}

func newExternalResolutionSummaryFromModuleResolutionResult(
	modules []string,
	mrr *swift.ModuleResolutionResult,
) ExternalResolutionSummary {
	if mrr == nil {
		return ExternalResolutionSummary{}
	}
	ers := ExternalResolutionSummary{
		Modules:    modules,
		Unresolved: mrr.Unresolved,
		Products:   make([]Product, len(mrr.Products)),
	}
	for idx, p := range mrr.Products {
		ers.Products[idx] = newProductFromSwiftProduct(p)
	}
	sort.Strings(ers.Modules)
	sort.Strings(ers.Unresolved)
	slices.SortFunc(ers.Products, func(a, b Product) int {
		akey := a.Identity + a.Name
		bkey := b.Identity + b.Name
		if akey < bkey {
			return -1
		}
		if akey == bkey {
			return 0
		}
		return 1
	})
	return ers
}
