package swift

import (
	"encoding/json"
	"sort"
)

type ModuleIndex map[string]Modules

// func (mi ModuleIndex) Add(m *Module) {
// 	modules := mi[m.Name]
// 	modules = append(modules, m)
// 	mi[m.Name] = modules
// }

func (mi ModuleIndex) Add(modules ...*Module) {
	for _, m := range modules {
		cur_modules := mi[m.Name]
		cur_modules = append(cur_modules, m)
		mi[m.Name] = cur_modules
	}
}

// Find the module given the Bazel repo name and the Swift module name.
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

func (mi ModuleIndex) ModuleNames() []string {
	names := make([]string, len(mi))
	idx := 0
	for modName := range mi {
		names[idx] = modName
		idx++
	}
	return names
}

func (mi ModuleIndex) jsonData() map[string][]string {
	jd := make(map[string][]string)
	for mname, modules := range mi {
		names := modules.ModuleNames()
		sort.Strings(names)
		jd[mname] = names
	}
	return jd
}

func (mi ModuleIndex) MarshalJSON() ([]byte, error) {
	return json.Marshal(mi.jsonData())
}
