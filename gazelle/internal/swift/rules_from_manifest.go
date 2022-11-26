package swift

import (
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

func RulesFromManifest(args language.GenerateArgs, pi *swiftpkg.PackageInfo) []*rule.Rule {
	return nil
}
