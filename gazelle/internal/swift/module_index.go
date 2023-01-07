package swift

import (
	"encoding/json"
	"sort"
)

type ModuleIndex map[string]Modules

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
	sort.Strings(names)
	return names
}

type moduleIndexJSONData map[string]LabelStrs

func (mi ModuleIndex) jsonData() moduleIndexJSONData {
	jd := make(moduleIndexJSONData)
	for mname, modules := range mi {
		jd[mname] = modules.LabelStrs()
	}
	return jd
}

func (mi ModuleIndex) MarshalJSON() ([]byte, error) {
	return json.Marshal(mi.jsonData())
}

func (mi *ModuleIndex) UnmarshalJSON(b []byte) error {
	var jd moduleIndexJSONData
	if err := json.Unmarshal(b, &jd); err != nil {
		return err
	}
	newmi := make(ModuleIndex)
	for mname, lblStrs := range jd {
		for _, lblStr := range lblStrs {
			l, err := NewLabel(lblStr)
			if err != nil {
				return err
			}
			newmi.Add(NewModule(mname, l))
		}
	}
	*mi = newmi
	return nil
}
