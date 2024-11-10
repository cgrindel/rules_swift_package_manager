package swift

import (
	"fmt"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spreso"
)

type commitProvider interface {
	Commit() string
}

// RepoRuleFromBazelRepo returns a repository rule declaration for a Swift Bazel repository.
// The pkgDir is the path to the Swift package that is referencing this Bazel repository.
func RepoRuleFromBazelRepo(
	bzlRepo *BazelRepo,
	diRel string,
	pkgDir string,
	repoDir string,
	patch *Patch,
) (*rule.Rule, error) {
	var r *rule.Rule
	var err error
	if bzlRepo.Pin != nil {
		r, err = repoRuleFromPin(bzlRepo.Name, bzlRepo.Pin, patch)
		if err != nil {
			return nil, err
		}
	} else {
		// For local packages, the `path` attribute must be relative to the WORKSPACE file.
		// However, since the Package.swift can exist anywhere in the repository, we need to
		// resolve the relative path from the package directory and then get the relative path from the WORKSPACE.
		relPathFromPkgDir, err := filepath.Rel(pkgDir, bzlRepo.PkgInfo.Path)
		if err != nil {
			return nil, err
		}
		absPathFromPkgDir := filepath.Join(pkgDir, relPathFromPkgDir)
		relPath, err := filepath.Rel(repoDir, absPathFromPkgDir)
		if err != nil {
			return nil, err
		}

		r = repoRuleForLocalPackage(bzlRepo.Name, relPath)
	}

	// The module index is located at the root of the parent workspace.
	dir := filepath.Dir(diRel)
	if dir == "." {
		dir = ""
	}
	lpath := filepath.ToSlash(dir)
	base := filepath.Base(diRel)
	miLbl := label.New("@", lpath, base)
	r.SetAttr("dependencies_index", miLbl.String())

	return r, nil
}

// The modules parameter is a map of the module name (key) to the relative Bazel label (value).
func repoRuleFromPin(repoName string, p *spreso.Pin, patch *Patch) (*rule.Rule, error) {
	cp, ok := p.State.(commitProvider)
	if !ok {
		return nil, fmt.Errorf("expected pin state to provide a commit hash %T", p.State)
	}

	r := rule.NewRule(SwiftPkgRuleKind, repoName)
	r.SetAttr("commit", cp.Commit())
	r.SetAttr("remote", p.PkgRef.Remote())
	if patch != nil {
		r.SetAttr("patches", patch.Files)
		if len(patch.Args) > 0 {
			r.SetAttr("patch_args", patch.Args)
		}
		if len(patch.Cmds) > 0 {
			r.SetAttr("patch_cmds", patch.Cmds)
		}
		if len(patch.WinCmds) > 0 {
			r.SetAttr("patch_cmds_win", patch.WinCmds)
		}
		if patch.Tool != "" {
			r.SetAttr("patch_tool", patch.Tool)
		}
	}

	switch t := p.State.(type) {
	case *spreso.VersionPinState:
		r.AddComment(fmt.Sprintf("# version: %s", t.Version))
	case *spreso.BranchPinState:
		r.AddComment(fmt.Sprintf("# branch: %s", t.Name))
	}

	return r, nil
}

func repoRuleForLocalPackage(repoName string, path string) *rule.Rule {
	r := rule.NewRule(LocalSwiftPkgRuleKind, repoName)
	r.SetAttr("path", path)
	return r
}
