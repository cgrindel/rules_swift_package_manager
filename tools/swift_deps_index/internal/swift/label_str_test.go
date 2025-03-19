package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestLabelStr(t *testing.T) {
	t.Run("round trip", func(t *testing.T) {
		l := label.New("my_repo", "path/to/pkg", "foo")
		ls := swift.NewLabelStr(&l)
		newl, err := swift.NewLabel(ls)
		assert.NoError(t, err)
		assert.Equal(t, &l, newl)
	})
}
