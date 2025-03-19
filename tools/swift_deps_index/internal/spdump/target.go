package spdump

import (
	"encoding/json"
	"errors"
	"fmt"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/jsonutils"
)

// A TargetType is an enum for a Swift target type.
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

// A Target represents a Swift target.
type Target struct {
	Name         string
	Type         TargetType
	Dependencies []TargetDependency
	Settings     []TargetSetting
}

func (t *Target) Imports() []string {
	imports := make([]string, len(t.Dependencies))
	for idx, td := range t.Dependencies {
		imports[idx] = td.ImportName()
	}
	return imports
}

// Targets

// A Targets represents a slice of Swift targets.
type Targets []Target

// FindByName returns the target with the matching name. Otherwise, it returns nil.
func (ts Targets) FindByName(name string) *Target {
	for _, t := range ts {
		if t.Name == name {
			return &t
		}
	}
	return nil
}

// TargetSetting

// A ToolType is an enum representing tool setting type.
type ToolType int

const (
	UnknownToolType ToolType = iota
	ClangToolType
)

// A TargetSettingKind is an enum represeting the kind for a tool setting.
type TargetSettingKind int

const (
	UnknownTargetSettingKind = iota
	DefineTargetSettingKind
)

// A TargetSetting represents customized settings for a target.
type TargetSetting struct {
	Tool    ToolType
	Kind    TargetSettingKind
	Defines []string
}

func (ts *TargetSetting) UnmarshalJSON(b []byte) error {
	var anyMap map[string]any
	err := json.Unmarshal(b, &anyMap)
	if err != nil {
		return err
	}

	toolStr, err := jsonutils.StringAtKey(anyMap, "tool")
	if err != nil {
		return err
	}
	switch toolStr {
	case "c":
		ts.Tool = ClangToolType
	default:
		ts.Tool = UnknownToolType
	}

	kindMap, err := jsonutils.MapAtKey(anyMap, "kind")
	if err != nil {
		return err
	}
	var mke *jsonutils.MissingKeyError
	if defineMap, err := jsonutils.MapAtKey(kindMap, "define"); err != nil {
		if !errors.As(err, &mke) {
			return err
		}
	} else {
		ts.Kind = DefineTargetSettingKind
		for _, anyVal := range defineMap {
			switch define := anyVal.(type) {
			case string:
				ts.Defines = append(ts.Defines, define)
			default:
				return fmt.Errorf("unexpected type %T for define value", define)
			}
		}
	}

	return nil
}
