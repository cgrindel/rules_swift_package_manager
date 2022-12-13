package swift

import (
	"log"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

type ModuleIndex struct {
	// Key: Module name
	// Value: Slice of module pointers
	index map[string][]*Module
}

func NewModuleIndex() *ModuleIndex {
	return &ModuleIndex{
		index: make(map[string][]*Module),
	}
}

func (mi *ModuleIndex) AddModule(m *Module) {
	modules := mi.index[m.Name]
	modules = append(modules, m)
	mi.index[m.Name] = modules
}

// Find the module given the Bazel repo name and the Swift module name.
func (mi *ModuleIndex) Resolve(repoName, moduleName string) *Module {
	modules := mi.index[moduleName]
	// DEBUG BEGIN
	log.Printf("*** CHUCK: Resovle ------")
	log.Printf("*** CHUCK: Resolve moduleName: %+#v", moduleName)
	log.Printf("*** CHUCK: Resolve modules: ")
	for idx, item := range modules {
		log.Printf("*** CHUCK %d: %+#v", idx, item)
	}
	// DEBUG END
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
	names := make([]string, len(mi.index))
	idx := 0
	for modName := range mi.index {
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
