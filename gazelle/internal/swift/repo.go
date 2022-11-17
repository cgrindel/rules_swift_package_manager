package swift

import (
	"fmt"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

const httpArchiveRuleKind = "http_archive"
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

func NewHTTPArchivesFromWkspFile(f *rule.File) ([]*HTTPArchive, error) {
	var archives []*HTTPArchive
	for _, r := range f.Rules {
		if r.Kind() != httpArchiveRuleKind {
			continue
		}
		ha, err := newHTTPArchiveFromRule(r)
		if err != nil {
			return nil, err
		}
		if ha != nil {
			archives = append(archives, ha)
		}
	}
	return archives, nil
}

func newHTTPArchiveFromRule(r *rule.Rule) (*HTTPArchive, error) {
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
