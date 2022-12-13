package swift

import (
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spdesc"
)

func BazelLabelFromTarget(repoName string, target *spdesc.Target) string {
	lbl := label.New(repoName, target.Path, target.Name)
	return lbl.String()
}
