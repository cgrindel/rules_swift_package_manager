package swift

import (
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

// Represents a Swift module mapped to a Bazel target.
type Module struct {
	Name    string       `json:"name"`
	C99name string       `json:"c99name"`
	Label   *label.Label `json:"label"`
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

func NewModuleFromTarget(repoName string, t *swiftpkg.Target) (*Module, error) {
	lbl := BazelLabelFromTarget(repoName, t)
	return NewModule(t.Name, t.C99name, lbl), nil
}

func (m *Module) LabelStr() LabelStr {
	return NewLabelStr(m.Label)
}

// Modules

type Modules []*Module

func (modules Modules) LabelStrs() LabelStrs {
	labelStrs := make(LabelStrs, len(modules))
	for idx, m := range modules {
		labelStrs[idx] = NewLabelStr(m.Label)
	}
	return labelStrs
}
