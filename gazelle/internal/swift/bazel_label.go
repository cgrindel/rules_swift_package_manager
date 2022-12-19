package swift

import (
	"path"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

func BazelLabelFromTarget(repoName string, target *swiftpkg.Target) label.Label {
	var name string
	basename := path.Base(target.Path)
	if basename == target.Name {
		name = target.Path
	} else {
		name = path.Join(target.Path, target.Name)
	}
	name = strings.ReplaceAll(name, "/", "_")
	return label.New(repoName, "", name)
}
