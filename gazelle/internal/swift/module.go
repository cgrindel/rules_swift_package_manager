package swift

import "github.com/bazelbuild/bazel-gazelle/label"

// Represents a Swift module mapped to a Bazel target.
type Module struct {
	Name   string
	Target label.Label
}

func NewModule(name string, target label.Label) *Module {
	return &Module{
		Name:   name,
		Target: target,
	}
}
