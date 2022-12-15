package swift

import (
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

type ModuleIndex struct {
	// Key: Module name
	// Value: Slice of module pointers
	byName map[string][]*Module
}

func NewModuleIndex() *ModuleIndex {
	return &ModuleIndex{
		byName: make(map[string][]*Module),
	}
}

func (mi *ModuleIndex) AddModule(m *Module) {
	modules := mi.byName[m.Name]
	modules = append(modules, m)
	mi.byName[m.Name] = modules
}

// Find the module given the Bazel repo name and the Swift module name.
func (mi *ModuleIndex) Resolve(repoName, moduleName string) *Module {
	modules := mi.byName[moduleName]
	if len(modules) == 0 {
		return nil
	}
	// Look for module with the same repo name
	for _, module := range modules {
		if repoName == module.Label.Repo {
			return module
		}
	}
	// Else pick the first one
	return modules[0]
}

func (mi *ModuleIndex) ModuleNames() []string {
	names := make([]string, len(mi.byName))
	idx := 0
	for modName := range mi.byName {
		names[idx] = modName
		idx++
	}
	return names
}

func (mi *ModuleIndex) AddModules(modules ...*Module) {
	for _, m := range modules {
		mi.AddModule(m)
	}
}

func (mi *ModuleIndex) IndexRepoRule(r *rule.Rule) error {
	var err error
	switch r.Kind() {
	case SwiftPkgRuleKind:
		err = mi.indexSwiftPkg(r)
	case HTTPArchiveRuleKind:
		err = mi.indexHTTPArchive(r)
	}
	return err
}

func (mi *ModuleIndex) indexSwiftPkg(r *rule.Rule) error {
	repoName := r.Name()
	modules, err := attrStringDict(r, "modules")
	if err != nil {
		return err
	}
	for moduleName, relLbl := range modules {
		lbl, err := label.Parse("@" + repoName + relLbl)
		if err != nil {
			return err
		}
		mod := NewModule(moduleName, lbl)
		mi.AddModule(mod)
	}
	return nil
}

func (mi *ModuleIndex) indexHTTPArchive(r *rule.Rule) error {
	ha, err := NewHTTPArchiveFromRule(r)
	if err != nil {
		return err
	}
	if ha == nil {
		return nil
	}
	mi.AddModules(ha.Modules...)
	return nil
}

func (mi *ModuleIndex) IndexPkgInfo(pi *swiftpkg.PackageInfo, repoName string) error {
	var err error

	// Index targets
	modules := make([]*Module, len(pi.Targets))
	for idx, t := range pi.Targets {
		modules[idx], err = NewModuleFromTarget(repoName, t)
		if err != nil {
			return err
		}
	}

	// Index products
	// TODO(chuck): Index products

	mi.AddModules(modules...)

	return nil
}

func (mi *ModuleIndex) BazelMap() map[string][]string {
	bzlMap := make(map[string][]string)
	for modName, mods := range mi.byName {
		// TODO(chuck): Sort the labels for consistent output?
		labels := make([]string, len(mods))
		for idx, mod := range mods {
			labels[idx] = mod.Label.String()
		}
		bzlMap[modName] = labels
	}
	return bzlMap
}
