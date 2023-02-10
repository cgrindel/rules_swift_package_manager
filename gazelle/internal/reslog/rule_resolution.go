package reslog

import (
	"github.com/bazelbuild/bazel-gazelle/resolve"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	mapset "github.com/deckarep/golang-set/v2"
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

func (rr *RuleResolution) AddUnresolved(moduleName string) {
	rr.UnresModuleNames.Add(moduleName)
}

func (rr *RuleResolution) String() string {
	// TODO(chuck): IMPLEMENT ME!
	return ""
}
