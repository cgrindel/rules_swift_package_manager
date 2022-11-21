package jsonutils_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonutils"
	"github.com/stretchr/testify/assert"
)

type myStruct struct {
	Name string `json:"name"`
}

var rawMap map[string]any
var mapValue map[string]any
var structValue map[string]any
var stringSliceValue = []any{"hello", "goodbye"}
var intSliceValue = []any{123, 456}

func init() {
	mapValue = make(map[string]any)
	mapValue["foo"] = "bar"

	structValue = make(map[string]any)
	structValue["name"] = "harry"

	rawMap = make(map[string]any)
	rawMap["stringKey"] = "stringValue"
	rawMap["intKey"] = 123
	rawMap["mapKey"] = mapValue
	rawMap["stringSliceKey"] = stringSliceValue
	rawMap["structKey"] = structValue
	rawMap["intSliceKey"] = intSliceValue
}

func TestStringAtKey(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		actual, ok := jsonutils.StringAtKey(rawMap, "doesNotExist")
		assert.False(t, ok)
		assert.Equal(t, "", actual)
	})
	t.Run("key exists, is not string", func(t *testing.T) {
		actual, ok := jsonutils.StringAtKey(rawMap, "intKey")
		assert.False(t, ok)
		assert.Equal(t, "", actual)
	})
	t.Run("key exists, is string", func(t *testing.T) {
		actual, ok := jsonutils.StringAtKey(rawMap, "stringKey")
		assert.True(t, ok)
		assert.Equal(t, "stringValue", actual)
	})
}

func TestMapAtKey(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		actual, ok := jsonutils.MapAtKey(rawMap, "doesNotExist")
		assert.False(t, ok)
		assert.Nil(t, actual)
	})
	t.Run("key exists, is not map", func(t *testing.T) {
		actual, ok := jsonutils.MapAtKey(rawMap, "intKey")
		assert.False(t, ok)
		assert.Nil(t, actual)
	})
	t.Run("key exists, is map", func(t *testing.T) {
		actual, ok := jsonutils.MapAtKey(rawMap, "mapKey")
		assert.True(t, ok)
		assert.Equal(t, mapValue, actual)
	})
}

func TestSliceAtKey(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		actual, ok := jsonutils.SliceAtKey(rawMap, "doesNotExist")
		assert.False(t, ok)
		assert.Nil(t, actual)
	})
	t.Run("key exists, is not slice", func(t *testing.T) {
		actual, ok := jsonutils.SliceAtKey(rawMap, "intKey")
		assert.False(t, ok)
		assert.Nil(t, actual)
	})
	t.Run("key exists, is slice", func(t *testing.T) {
		actual, ok := jsonutils.SliceAtKey(rawMap, "stringSliceKey")
		assert.True(t, ok)
		assert.Equal(t, stringSliceValue, actual)
	})
}

func TestUnmarshalAtKey(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		var v myStruct
		ok := jsonutils.UnmarshalAtKey(rawMap, "doesNotExist", &v)
		assert.False(t, ok)
	})
	t.Run("key exists, unmarshal succeeds", func(t *testing.T) {
		var v myStruct
		ok := jsonutils.UnmarshalAtKey(rawMap, "structKey", &v)
		assert.True(t, ok)
		expected := myStruct{Name: "harry"}
		assert.Equal(t, expected, v)
	})
}

func TestStringsAtKey(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		actual, ok := jsonutils.StringsAtKey(rawMap, "doesNotExist")
		assert.False(t, ok)
		assert.Nil(t, actual)
	})
	t.Run("key is not a slice of strings", func(t *testing.T) {
		actual, ok := jsonutils.StringsAtKey(rawMap, "intSliceKey")
		assert.False(t, ok)
		assert.Nil(t, actual)
	})
	t.Run("key is a slice of strings", func(t *testing.T) {
		actual, ok := jsonutils.StringsAtKey(rawMap, "stringSliceKey")
		assert.True(t, ok)
		assert.Equal(t, []string{"hello", "goodbye"}, actual)
	})
}
