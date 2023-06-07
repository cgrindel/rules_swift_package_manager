package swift_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestNePatchDirectiveFromYAML(t *testing.T) {
	t.Run("success", func(t *testing.T) {
		str := `{identity: swift-cmark, args: ['-p1'], files: ['@@//third-party/swift-cmark:0001-foo.patch']}`
		// str := `identity: swift-cmark`
		actual, err := swift.NewPatchDirectiveFromYAML(str)
		assert.NoError(t, err)
		expected := &swift.PatchDirective{
			Identity: "swift-cmark",
			Patch: swift.Patch{
				Args:  []string{"-p1"},
				Files: []string{"@@//third-party/swift-cmark:0001-foo.patch"},
			},
		}
		assert.Equal(t, expected, actual)
	})
	t.Run("fail", func(t *testing.T) {
		str := "garbage/foo"
		actual, err := swift.NewPatchDirectiveFromYAML(str)
		assert.Error(t, err)
		assert.Nil(t, actual)
	})
}
