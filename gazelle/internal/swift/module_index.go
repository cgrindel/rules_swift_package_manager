package swift

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

func (mi *ModuleIndex) AddModules(modules ...*Module) {
	for _, m := range modules {
		mi.AddModule(m)
	}
}
