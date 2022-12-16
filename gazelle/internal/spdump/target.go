package spdump

import "encoding/json"

type TargetType int

const (
	UnknownTargetType TargetType = iota
	ExecutableTargetType
	LibraryTargetType
	TestTargetType
	PluginTargetType
)

func (tt *TargetType) UnmarshalJSON(b []byte) error {
	var ttStr string
	err := json.Unmarshal(b, &ttStr)
	if err != nil {
		return err
	}
	switch ttStr {
	case "executable":
		*tt = ExecutableTargetType
	case "test":
		*tt = TestTargetType
	case "library", "regular":
		*tt = LibraryTargetType
	case "plugin":
		*tt = PluginTargetType
	default:
		*tt = UnknownTargetType
	}
	return nil
}

type Target struct {
	Name         string
	Type         TargetType
	Dependencies []TargetDependency
}

func (t *Target) Imports() []string {
	imports := make([]string, len(t.Dependencies))
	for idx, td := range t.Dependencies {
		imports[idx] = td.ImportName()
	}
	return imports
}

// Targets

type Targets []Target

func (ts Targets) FindByName(name string) *Target {
	for _, t := range ts {
		if t.Name == name {
			return &t
		}
	}
	return nil
}
