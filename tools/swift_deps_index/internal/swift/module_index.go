package swift

import (
	"sort"
)

// A ModuleIndex represents an index organized by module name.
type ModuleIndex map[string]Modules

// NewModuleIndex creates a new module index populated with the provided modules.
func NewModuleIndex(modules ...*Module) ModuleIndex {
	mi := make(ModuleIndex)
	mi.Add(modules...)
	return mi
}

func (mi ModuleIndex) add(name string, m *Module) {
	cur_modules := mi[name]
	cur_modules = append(cur_modules, m)
	mi[name] = cur_modules
}

// Add indexes the provided modules.
func (mi ModuleIndex) Add(modules ...*Module) {
	for _, m := range modules {
		mi.add(m.Name, m)
		if m.Name != m.C99name {
			mi.add(m.C99name, m)
		}
	}
}

// Resolve finds the module given the Bazel repo name and the Swift module name.
func (mi ModuleIndex) Resolve(repoName, moduleName string) *Module {
	modules := mi[moduleName]
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

// Modules returns a unique list of modules.
func (mi ModuleIndex) Modules() Modules {
	var labels []string
	byLabel := make(map[string]*Module)
	for _, modules := range mi {
		for _, m := range modules {
			l := m.Label.String()
			if _, ok := byLabel[l]; !ok {
				byLabel[l] = m
				labels = append(labels, l)
			}
		}
	}
	sort.Strings(labels)
	result := make(Modules, len(labels))
	for idx, l := range labels {
		result[idx] = byLabel[l]
	}
	return result
}
