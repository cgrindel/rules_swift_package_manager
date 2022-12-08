package spdump

import "strings"

type TargetType int

const (
	UnknownTargetType TargetType = iota
	ExecutableTargetType
	LibraryTargetType
	TestTargetType
)

func (tt *TargetType) UnmarshalJSON(b []byte) error {
	// The bytes are a raw string (i.e., includes double quotes at front and back). Remove them.
	ttStr := strings.Trim(string(b), "\"")
	switch ttStr {
	case "executable":
		*tt = ExecutableTargetType
	case "test":
		*tt = TestTargetType
	case "library":
		*tt = LibraryTargetType
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
