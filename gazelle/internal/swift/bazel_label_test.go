package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestBazelLabelFromTarget(t *testing.T) {
	target := &swiftpkg.Target{
		Name: "Foo",
		Path: "Sources/Foo",
	}
	actual := swift.BazelLabelFromTarget("example_cool_repo", target)
	expected, err := label.Parse("@example_cool_repo//:Sources_Foo")
	assert.NoError(t, err)
	assert.Equal(t, &expected, actual)
}
