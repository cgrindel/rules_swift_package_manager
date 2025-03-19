package swift

import (
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
)

const modulemapLabelNameSuffix = "_modulemap"
const targetLabelNameSuffix = ".rspm"

// BazelLabelFromTarget creates a Bazel label from a Swift target.
// The logic in this function must stay in sync with
// pkginfo_targets.bazel_label_name_from_parts() in the Starlark code.
func BazelLabelFromTarget(repoName string, target *swiftpkg.Target) *label.Label {
	lbl := label.New(repoName, "", target.Name+targetLabelNameSuffix)
	return &lbl
}

// ModulemapBazelLabelFromTargetLabel creates a Bazel label for a modulemap target from the
// corresponding target label.
func ModulemapBazelLabelFromTargetLabel(lbl *label.Label) *label.Label {
	mml := label.New(lbl.Repo, lbl.Pkg, lbl.Name+modulemapLabelNameSuffix)
	return &mml
}
