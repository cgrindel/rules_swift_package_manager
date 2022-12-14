package swift

import (
	"fmt"

	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
)

type commitProvider interface {
	Commit() string
}

// The modules parameter is a map of the module name (key) to the relative Bazel label (value).
func RepoRuleFromPin(p *spreso.Pin, modules map[string]string, miBasename string) (*rule.Rule, error) {
	repoName, err := RepoNameFromPin(p)
	if err != nil {
		return nil, err
	}
	cp, ok := p.State.(commitProvider)
	if !ok {
		return nil, fmt.Errorf("expected pin state to provide a commit hash %T", p.State)
	}

	r := rule.NewRule(SwiftPkgRuleKind, repoName)
	r.SetAttr("commit", cp.Commit())
	r.SetAttr("remote", p.PkgRef.Remote())
	r.SetAttr("modules", modules)
	r.SetAttr("module_index", miBasename)

	switch t := p.State.(type) {
	case *spreso.VersionPinState:
		r.AddComment(fmt.Sprintf("# version: %s", t.Version))
	case *spreso.BranchPinState:
		r.AddComment(fmt.Sprintf("# branch: %s", t.Name))
	}

	return r, nil
}
