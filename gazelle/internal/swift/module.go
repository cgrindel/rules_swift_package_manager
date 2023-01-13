package swift

import (
	"encoding/json"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

// Module represents a Swift module mapped to a Bazel target.
type Module struct {
	Name    string
	C99name string
	Label   *label.Label
}

func NewModule(name, c99name string, bzlLabel *label.Label) *Module {
	return &Module{
		Name:    name,
		C99name: c99name,
		Label:   bzlLabel,
	}
}

// NewModuleFromLabelStruct is a convenience function because label.New returns a struct, not a
// pointer.
func NewModuleFromLabelStruct(name, c99name string, bzlLabel label.Label) *Module {
	return NewModule(name, c99name, &bzlLabel)
}

// NewModuleFromTarget returns a module from the specified Swift target.
func NewModuleFromTarget(repoName string, t *swiftpkg.Target) (*Module, error) {
	lbl := BazelLabelFromTarget(repoName, t)
	return NewModule(t.Name, t.C99name, lbl), nil
}

// LabelStr returns the label string for module.
func (m *Module) LabelStr() LabelStr {
	return NewLabelStr(m.Label)
}

// Modules

// A Modules represents a slice of Swift modules.
type Modules []*Module

// LabelStrs returns the label strings for the modules.
func (modules Modules) LabelStrs() LabelStrs {
	labelStrs := make(LabelStrs, len(modules))
	for idx, m := range modules {
		labelStrs[idx] = NewLabelStr(m.Label)
	}
	return labelStrs
}

type moduleJSONData struct {
	Name    string `json:"name"`
	C99name string `json:"c99name"`
	Label   string `json:"label"`
}

func (m *Module) MarshalJSON() ([]byte, error) {
	jd := &moduleJSONData{
		Name:    m.Name,
		C99name: m.C99name,
		Label:   m.Label.String(),
	}
	return json.Marshal(&jd)
}

func (m *Module) UnmarshalJSON(b []byte) error {
	var jd moduleJSONData
	if err := json.Unmarshal(b, &jd); err != nil {
		return err
	}
	l, err := label.Parse(jd.Label)
	if err != nil {
		return err
	}
	newm := NewModule(jd.Name, jd.C99name, &l)
	*m = *newm
	return nil
}
