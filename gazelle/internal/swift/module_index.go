package swift

type ModuleIndex struct {
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

func (mi *ModuleIndex) Resolve(repoName, moduleName string) *Module {
	modules := mi.index[moduleName]
	// // DEBUG BEGIN
	// log.Printf("*** CHUCK: ModuleIndex.Resolve repoName: %+#v", repoName)
	// log.Printf("*** CHUCK: ModuleIndex.Resolve moduleName: %+#v", moduleName)
	// log.Printf("*** CHUCK: ModuleIndex.Resolve modules: ")
	// for idx, item := range modules {
	// 	log.Printf("*** CHUCK %d: %+#v", idx, item)
	// }
	// // DEBUG END
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
