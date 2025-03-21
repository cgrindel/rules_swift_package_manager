package swift_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestNewPatchesFromYAML(t *testing.T) {
	t.Run("success", func(t *testing.T) {
		str := `swift-cmark:
  args: ['-p1']
  files: ['@@//third-party/swift-cmark:0001-foo.patch']
foo:
  files: ['@@//third-party/foo:0001-foo.patch']
`
		actual, err := swift.NewPatchesFromYAML([]byte(str))
		assert.NoError(t, err)
		expected := map[string]*swift.Patch{
			"swift-cmark": {
				Args:  []string{"-p1"},
				Files: []string{"@@//third-party/swift-cmark:0001-foo.patch"},
			},
			"foo": {
				Files: []string{"@@//third-party/foo:0001-foo.patch"},
			},
		}
		assert.Equal(t, expected, actual)
	})
	t.Run("fail", func(t *testing.T) {
		str := "garbage/foo"
		actual, err := swift.NewPatchesFromYAML([]byte(str))
		assert.Error(t, err)
		assert.Nil(t, actual)
	})
}
