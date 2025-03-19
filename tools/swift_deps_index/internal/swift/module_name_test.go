package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestModuleName(t *testing.T) {
	t.Run("has module_name attribute", func(t *testing.T) {
		r := rule.NewRule("swift_library", "foo")
		r.SetAttr(swift.ModuleNameAttrName, "Foo")
		actual := swift.ModuleName(r)
		assert.Equal(t, "Foo", actual)
	})
	t.Run("does not have module_name attribute", func(t *testing.T) {
		r := rule.NewRule("swift_library", "Foo")
		actual := swift.ModuleName(r)
		assert.Equal(t, "Foo", actual)
	})
}
