package reslog

import (
	"sort"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
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

func moduleLabelLess(a, b ModuleLabel) bool {
	return a.Module < b.Module
}

type Product struct {
	Identity string
	Name     string
	Labels   []string
}

func newProductFromSwiftProduct(p *swift.Product) Product {
	prd := Product{
		Identity: p.Identity,
		Name:     p.Name,
		Labels:   make([]string, len(p.TargetLabels)),
	}
	for idx, l := range p.TargetLabels {
		prd.Labels[idx] = l.String()
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
	slices.SortFunc(ers.Products, func(a, b Product) bool {
		akey := a.Identity + a.Name
		bkey := b.Identity + b.Name
		return akey < bkey
	})
	return ers
}
