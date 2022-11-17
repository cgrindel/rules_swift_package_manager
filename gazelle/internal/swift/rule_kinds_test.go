package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestIsSwiftRuleKind(t *testing.T) {
	assert.True(t, swift.IsSwiftRuleKind(swift.LibraryRuleKind))
	assert.True(t, swift.IsSwiftRuleKind(swift.BinaryRuleKind))
	assert.True(t, swift.IsSwiftRuleKind(swift.TestRuleKind))
	assert.False(t, swift.IsSwiftRuleKind("go_library"))
}
