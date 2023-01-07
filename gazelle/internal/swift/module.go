package swift

import (
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

// Represents a Swift module mapped to a Bazel target.
type Module struct {
	Name  string
	Label label.Label
}

func NewModule(name string, bzlLabel label.Label) *Module {
	return &Module{
		Name:  name,
		Label: bzlLabel,
	}
}

func NewModuleFromTarget(repoName string, t *swiftpkg.Target) (*Module, error) {
	lbl := BazelLabelFromTarget(repoName, t)
	return NewModule(t.C99name, lbl), nil
}

// Modules

type Modules []*Module

func (modules Modules) ModuleNames() []string {
	names := make([]string, len(modules))
	for idx, m := range modules {
		names[idx] = m.Label.String()
	}
	return names
}
