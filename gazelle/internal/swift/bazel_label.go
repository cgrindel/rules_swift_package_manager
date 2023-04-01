package swift

import (
	"path"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swiftpkg"
)

// BazelLabelFromTarget creates a Bazel label from a Swift target.
func BazelLabelFromTarget(repoName string, target *swiftpkg.Target) *label.Label {
	var name string
	basename := path.Base(target.Path)
	if basename == target.Name {
		name = target.Path
	} else {
		name = path.Join(target.Path, target.Name)
	}
	name = strings.ReplaceAll(name, "/", "_")
	lbl := label.New(repoName, "", name)
	return &lbl
}
