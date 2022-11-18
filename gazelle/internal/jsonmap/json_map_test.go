package jsonmap_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonmap"
	"github.com/stretchr/testify/assert"
)

var rawMap map[string]any
var mapValue map[string]any
var sliceValue = []any{"hello", "goodbye"}

func init() {
	mapValue = make(map[string]any)
	mapValue["foo"] = "bar"

	rawMap = make(map[string]any)
	rawMap["stringKey"] = "stringValue"
	rawMap["intKey"] = 123
	rawMap["mapKey"] = mapValue
	rawMap["sliceKey"] = sliceValue
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

func TestMap(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		actual, ok := jsonmap.Map(rawMap, "doesNotExist")
		assert.False(t, ok)
		assert.Nil(t, actual)
	})
	t.Run("key exists, is not map", func(t *testing.T) {
		actual, ok := jsonmap.Map(rawMap, "intKey")
		assert.False(t, ok)
		assert.Nil(t, actual)
	})
	t.Run("key exists, is map", func(t *testing.T) {
		actual, ok := jsonmap.Map(rawMap, "mapKey")
		assert.True(t, ok)
		assert.Equal(t, mapValue, actual)
	})
}

func TestSlice(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		actual, ok := jsonmap.Slice(rawMap, "doesNotExist")
		assert.False(t, ok)
		assert.Nil(t, actual)
	})
	t.Run("key exists, is not slice", func(t *testing.T) {
		actual, ok := jsonmap.Slice(rawMap, "intKey")
		assert.False(t, ok)
		assert.Nil(t, actual)
	})
	t.Run("key exists, is slice", func(t *testing.T) {
		actual, ok := jsonmap.Slice(rawMap, "sliceKey")
		assert.True(t, ok)
		assert.Equal(t, sliceValue, actual)
	})
}
