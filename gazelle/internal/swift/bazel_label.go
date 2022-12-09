package swift

import (
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spdesc"
)

func bazelLabelFromTarget(target *spdesc.Target) string {
	lbl := label.New("", target.Path, target.Name)
	return lbl.String()
}
