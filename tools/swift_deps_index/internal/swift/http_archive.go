package swift

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	"golang.org/x/exp/slices"
)

const buildFileContentAttrName = "build_file_content"
const buildFileAttrName = "build_file"
const HTTPArchivePkgIdentity = "__http_archive__"

// A HTTPArchive represents Swift module information found in a Bazel `http_archive` declaration.
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

// NewHTTPArchiveFromRule returns an HTTPArchive from a repository rule. If the repository does not
// provide any Swift modules, it returns nil.
func NewHTTPArchiveFromRule(r *rule.Rule, repoRoot string) (*HTTPArchive, error) {
	var err error
	bldFileContent := r.AttrString(buildFileContentAttrName)
	if bldFileContent == "" {
		bldFile := r.AttrString(buildFileAttrName)
		if bldFileContent, err = readBuildFileContent(bldFile, repoRoot); err != nil {
			return nil, err
		}
	}
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
		m := NewModule(moduleName, moduleName, swiftpkg.SwiftSourceType, &l,
			nil, HTTPArchivePkgIdentity, nil)
		modules = append(modules, m)
	}

	// Check if we found any Swift rules. If not, then we are done.
	if len(modules) == 0 {
		return nil, nil
	}

	return NewHTTPArchive(repoName, modules), nil
}

func readBuildFileContent(buildFile string, repoRoot string) (string, error) {
	if buildFile == "" {
		return "", nil
	}
	lbl, err := label.Parse(buildFile)
	if err != nil {
		return "", err
	}
	if !slices.Contains([]string{"", "@"}, lbl.Repo) {
		return "", fmt.Errorf("invalid repo name when trying to read build file %s", buildFile)
	}
	bldFilePath := filepath.Join(repoRoot, lbl.Pkg, lbl.Name)
	data, err := os.ReadFile(bldFilePath)
	if err != nil {
		return "", err
	}
	return string(data), nil
}
