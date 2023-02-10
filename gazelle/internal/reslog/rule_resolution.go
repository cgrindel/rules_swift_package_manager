package reslog

import (
	"sort"

	"github.com/bazelbuild/bazel-gazelle/resolve"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	mapset "github.com/deckarep/golang-set/v2"
	"golang.org/x/exp/slices"
)

type RuleResolution struct {
	Rule              *rule.Rule
	Imports           []string
	Builtins          mapset.Set[string]
	LocalRes          map[string][]resolve.FindResult
	ExtResModuleNames []string
	ExtResResult      *swift.ModuleResolutionResult
	HTTPArchiveRes    map[string]swift.Modules
	UnresModuleNames  mapset.Set[string]
}

func NewRuleResolution(r *rule.Rule, moduleNames []string) *RuleResolution {
	return &RuleResolution{
		Rule:             r,
		Imports:          moduleNames,
		Builtins:         mapset.NewSet[string](),
		LocalRes:         make(map[string][]resolve.FindResult),
		HTTPArchiveRes:   make(map[string]swift.Modules),
		UnresModuleNames: mapset.NewSet[string](),
	}
}

func (rr *RuleResolution) AddBuiltin(moduleName string) {
	rr.Builtins.Add(moduleName)
}

func (rr *RuleResolution) AddLocal(moduleName string, frs []resolve.FindResult) {
	rr.LocalRes[moduleName] = frs
}

func (rr *RuleResolution) AddExternal(moduleNames []string, mrr *swift.ModuleResolutionResult) {
	rr.ExtResModuleNames = moduleNames
	rr.ExtResResult = mrr
}

func (rr *RuleResolution) AddHTTPArchive(moduleName string, modules swift.Modules) {
	rr.HTTPArchiveRes[moduleName] = modules
}

func (rr *RuleResolution) AddUnresolved(moduleNames ...string) {
	for _, mname := range moduleNames {
		rr.UnresModuleNames.Add(mname)
	}
}

func (rr *RuleResolution) Summary() RuleResolutionSummary {
	yd := RuleResolutionSummary{
		Name:           rr.Rule.Name(),
		Kind:           rr.Rule.Kind(),
		Imports:        make([]string, len(rr.Imports)),
		Builtins:       rr.Builtins.ToSlice(),
		LocalRes:       make([]ModuleLabel, 0, len(rr.LocalRes)),
		ExtRes:         nil,
		HTTPArchiveRes: make([]ModuleLabel, 0, len(rr.HTTPArchiveRes)),
		Unresolved:     rr.UnresModuleNames.ToSlice(),
	}
	copy(yd.Imports, rr.Imports)
	for mname, frs := range rr.LocalRes {
		mt := ModuleLabel{Module: mname, Label: frs[0].Label.String()}
		yd.LocalRes = append(yd.LocalRes, mt)
	}
	yd.ExtRes = newExternalResolutionSummaryFromModuleResolutionResult(
		rr.ExtResModuleNames,
		rr.ExtResResult,
	)
	for mname, mods := range rr.HTTPArchiveRes {
		mt := ModuleLabel{Module: mname, Label: mods[0].Label.String()}
		yd.HTTPArchiveRes = append(yd.HTTPArchiveRes, mt)
	}

	sort.Strings(yd.Imports)
	sort.Strings(yd.Builtins)
	slices.SortFunc(yd.LocalRes, moduleLabelLess)
	slices.SortFunc(yd.HTTPArchiveRes, moduleLabelLess)
	sort.Strings(yd.Unresolved)

	return yd
}
