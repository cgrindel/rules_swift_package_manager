package swift

import (
	"encoding/json"
	"sort"
)

type ModuleIndex map[string]Modules

func (mi ModuleIndex) add(name string, m *Module) {
	cur_modules := mi[name]
	cur_modules = append(cur_modules, m)
	mi[name] = cur_modules
}

func (mi ModuleIndex) Add(modules ...*Module) {
	for _, m := range modules {
		mi.add(m.Name, m)
		if m.Name != m.C99name {
			mi.add(m.C99name, m)
		}
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
	sort.Strings(names)
	return names
}

// Return a unique list of modules.
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

// type moduleIndexJSONData map[string]LabelStrs

// func (mi ModuleIndex) jsonData() moduleIndexJSONData {
// 	jd := make(moduleIndexJSONData)
// 	for mname, modules := range mi {
// 		jd[mname] = modules.LabelStrs()
// 	}
// 	return jd
// }

func (mi ModuleIndex) MarshalJSON() ([]byte, error) {
	return json.Marshal(mi.Modules())
}

func (mi *ModuleIndex) UnmarshalJSON(b []byte) error {
	var modules Modules
	if err := json.Unmarshal(b, &modules); err != nil {
		return err
	}
	newmi := make(ModuleIndex)
	newmi.Add(modules...)
	*mi = newmi
	return nil

	// var jd moduleIndexJSONData
	// if err := json.Unmarshal(b, &jd); err != nil {
	// 	return err
	// }
	// newmi := make(ModuleIndex)
	// for mname, lblStrs := range jd {
	// 	for _, lblStr := range lblStrs {
	// 		l, err := NewLabel(lblStr)
	// 		if err != nil {
	// 			return err
	// 		}
	// 		newmi.Add(NewModule(mname, l))
	// 	}
	// }
	// *mi = newmi
	// return nil
}
