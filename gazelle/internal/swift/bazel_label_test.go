package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestBazelLabelFromTarget(t *testing.T) {
	target := &swiftpkg.Target{
		Name: "Foo",
		Path: "Sources/Foo",
	}
	actual := swift.BazelLabelFromTarget("example_cool_repo", target)
	expected := "@example_cool_repo//Sources/Foo"
	assert.Equal(t, expected, actual)
}
