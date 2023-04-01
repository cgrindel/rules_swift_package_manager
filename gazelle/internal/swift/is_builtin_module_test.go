package swift_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swift"
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
		// XCTest is unusual in that it does not appear in any of the framework lists, but it is
		// there.
		{msg: "XCTest", name: "XCTest", exp: true},
		{msg: "does not exist", name: "DoesNotExist", exp: false},
	}
	for _, tt := range tests {
		actual := swift.IsBuiltInModule(tt.name)
		assert.Equal(t, tt.exp, actual, tt.msg)
	}
}
