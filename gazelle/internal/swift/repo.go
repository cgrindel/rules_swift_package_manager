package swift

import "github.com/bazelbuild/bazel-gazelle/rule"

type HTTPArchive struct {
	Name    string
	Modules []*Module
}

func NewHTTPArchive(name string, modules []*Module) *HTTPArchive {
	return &HTTPArchive{
		Name:    name,
		Modules: modules,
	}
}

func NewHTTPArchiveFromRule(r *rule.Rule) (*HTTPArchive, error) {
	// TODO(chuck): IMPLEMENT ME!
	return nil, nil
}
