package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestModule(t *testing.T) {
	t.Run("label string", func(t *testing.T) {
		l := label.New("my_repo", "path/to/pkg", "Foo")
		m := swift.NewModule("Foo", "Foo", swiftpkg.SwiftSourceType, &l, nil, "my-repo", nil)
		actual := m.LabelStr()
		expected := swift.NewLabelStr(&l)
		assert.Equal(t, expected, actual)
	})
}

func TestModules(t *testing.T) {
	t.Run("get label strings", func(t *testing.T) {
		modules := swift.Modules{fooM, barM}
		actual := modules.LabelStrs()
		expected := swift.LabelStrs{
			swift.NewLabelStr(fooM.Label),
			swift.NewLabelStr(barM.Label),
		}
		assert.Equal(t, expected, actual)
	})
}
