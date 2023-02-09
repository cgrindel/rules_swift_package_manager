package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestIsBuiltInModule(t *testing.T) {
	tests := []struct {
		msg  string
		name string
		exp  bool
	}{
		{msg: "AppKit", name: "AppKit", exp: true},
		{msg: "UIKit", name: "UIKit", exp: true},
		{msg: "does not exist", name: "DoesNotExist", exp: false},
	}
	for _, tt := range tests {
		actual := swift.IsBuiltInModule(tt.name)
		assert.Equal(t, tt.exp, actual, tt.msg)
	}
}
