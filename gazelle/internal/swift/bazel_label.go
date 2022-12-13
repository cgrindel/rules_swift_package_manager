package swift

import (
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

func BazelLabelFromTarget(repoName string, target *swiftpkg.Target) string {
	lbl := label.New(repoName, target.Path, target.Name)
	return lbl.String()
}
