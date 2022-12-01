package swift

import (
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
)

func RepoRuleFromPin(p *spreso.Pin) (*rule.Rule, error) {
	repoName, err := RepoNameFromPin(p)
	if err != nil {
		return nil, err
	}
	r := rule.NewRule(SwiftPkgRuleKind, repoName)
	// TODO(chuck): Finish me!
	return r, nil
}
