package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdesc"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestBazelLabelFromTarget(t *testing.T) {
	target := &spdesc.Target{
		Name: "Foo",
		Path: "Sources/Foo",
	}
	actual := swift.BazelLabelFromTarget("example_cool_repo", target)
	expected := "@example_cool_repo//Sources/Foo"
	assert.Equal(t, expected, actual)
}
