package swift

import (
	"fmt"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

const buildFileContentAttrName = "build_file_content"

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
	bldFileContent := r.AttrString(buildFileContentAttrName)
	if bldFileContent == "" {
		return nil, nil
	}
	repoName := r.Name()
	path := filepath.Join(repoName, "BUILD.bazel")
	f, err := rule.LoadData(path, "", []byte(bldFileContent))
	if err != nil {
		return nil, fmt.Errorf("failed to parse build file contents for %s: %w", path, err)
	}
	var modules []*Module
	for _, br := range f.Rules {
		if !IsSwiftRuleKind(br.Kind()) {
			continue
		}
		moduleName := ModuleName(br)
		l := label.New(repoName, "", br.Name())
		m := NewModule(moduleName, l)
		modules = append(modules, m)
	}

	// Check if we found any Swift rules. If not, then we are done.
	if len(modules) == 0 {
		return nil, nil
	}

	return NewHTTPArchive(repoName, modules), nil
}
