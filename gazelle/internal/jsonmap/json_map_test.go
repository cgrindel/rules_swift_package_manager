package jsonmap_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonmap"
	"github.com/stretchr/testify/assert"
)

var rawMap map[string]any

func init() {
	rawMap = make(map[string]any)
	rawMap["stringKey"] = "stringValue"
	rawMap["intKey"] = 123
}

func TestString(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		actual, ok := jsonmap.String(rawMap, "doesNotExist")
		assert.False(t, ok)
		assert.Equal(t, "", actual)
	})
	t.Run("key exists, is not string", func(t *testing.T) {
		actual, ok := jsonmap.String(rawMap, "intKey")
		assert.False(t, ok)
		assert.Equal(t, "", actual)
	})
	t.Run("key exists, is string", func(t *testing.T) {
		actual, ok := jsonmap.String(rawMap, "stringKey")
		assert.True(t, ok)
		assert.Equal(t, "stringValue", actual)
	})
}
