package jsonutils_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/jsonutils"
	"github.com/stretchr/testify/assert"
)

func TestStringAtIndex(t *testing.T) {
	t.Run("index out of bounds", func(t *testing.T) {
		idx := 1
		actual, err := jsonutils.StringAtIndex(nil, idx)
		assert.Equal(t, jsonutils.NewIndexOutOfBoundsError(idx, 0), err)
		assert.Equal(t, "", actual)
	})
	t.Run("index value is not string", func(t *testing.T) {
		idx := 0
		actual, err := jsonutils.StringAtIndex(intSliceValue, idx)
		assert.Equal(t, jsonutils.NewIndexTypeError(idx, "string", intSliceValue[idx]), err)
		assert.Equal(t, "", actual)
	})
	t.Run("index value is string", func(t *testing.T) {
		idx := 0
		actual, err := jsonutils.StringAtIndex(stringSliceValue, idx)
		assert.NoError(t, err)
		assert.Equal(t, "hello", actual)
	})
}
