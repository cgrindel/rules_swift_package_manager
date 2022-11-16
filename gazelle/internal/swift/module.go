package swift

import "github.com/bazelbuild/bazel-gazelle/label"

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
