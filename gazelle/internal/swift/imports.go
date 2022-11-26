package swift

import (
	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

func Imports(rules []*rule.Rule) []any {
	imports := make([]interface{}, len(rules))
	for idx, r := range rules {
		imports[idx] = r.PrivateAttr(config.GazelleImportsKey)
	}
	return imports
}
