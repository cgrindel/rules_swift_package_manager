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
var intValue = 123
var stringValue = "stringValue"

func init() {
	mapValue = make(map[string]any)
	mapValue["foo"] = "bar"

	structValue = make(map[string]any)
	structValue["name"] = "harry"

	rawMap = make(map[string]any)
	rawMap["stringKey"] = stringValue
	rawMap["intKey"] = intValue
	rawMap["mapKey"] = mapValue
	rawMap["stringSliceKey"] = stringSliceValue
	rawMap["structKey"] = structValue
	rawMap["intSliceKey"] = intSliceValue
}

func TestStringAtKey(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		k := "doesNotExist"
		actual, err := jsonutils.StringAtKey(rawMap, k)
		assert.Equal(t, jsonutils.NewMissingKeyError(k), err)
		assert.Equal(t, "", actual)
	})
	t.Run("key exists, is not string", func(t *testing.T) {
		k := "intKey"
		actual, err := jsonutils.StringAtKey(rawMap, k)
		assert.Equal(t, jsonutils.NewKeyTypeError(k, "string", intValue), err)
		assert.Equal(t, "", actual)
	})
	t.Run("key exists, is string", func(t *testing.T) {
		actual, err := jsonutils.StringAtKey(rawMap, "stringKey")
		assert.NoError(t, err)
		assert.Equal(t, "stringValue", actual)
	})
}

func TestIntAtKey(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		k := "doesNotExist"
		actual, err := jsonutils.IntAtKey(rawMap, k)
		assert.Equal(t, jsonutils.NewMissingKeyError(k), err)
		assert.Equal(t, 0, actual)
	})
	t.Run("key exists, is not int", func(t *testing.T) {
		k := "stringKey"
		actual, err := jsonutils.IntAtKey(rawMap, k)
		assert.Equal(t, jsonutils.NewKeyTypeError(k, "int", stringValue), err)
		assert.Equal(t, 0, actual)
	})
	t.Run("key exists, is int", func(t *testing.T) {
		actual, err := jsonutils.IntAtKey(rawMap, "intKey")
		assert.NoError(t, err)
		assert.Equal(t, intValue, actual)
	})
}

func TestMapAtKey(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		k := "doesNotExist"
		actual, err := jsonutils.MapAtKey(rawMap, k)
		assert.Equal(t, jsonutils.NewMissingKeyError(k), err)
		assert.Nil(t, actual)
	})
	t.Run("key exists, is not map", func(t *testing.T) {
		k := "intKey"
		actual, err := jsonutils.MapAtKey(rawMap, "intKey")
		assert.Equal(t, jsonutils.NewKeyTypeError(k, "map[string]any", intValue), err)
		assert.Nil(t, actual)
	})
	t.Run("key exists, is map", func(t *testing.T) {
		actual, err := jsonutils.MapAtKey(rawMap, "mapKey")
		assert.NoError(t, err)
		assert.Equal(t, mapValue, actual)
	})
}

func TestSliceAtKey(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		k := "doesNotExist"
		actual, err := jsonutils.SliceAtKey(rawMap, "doesNotExist")
		assert.Equal(t, jsonutils.NewMissingKeyError(k), err)
		assert.Nil(t, actual)
	})
	t.Run("key exists, is not slice", func(t *testing.T) {
		k := "intKey"
		actual, err := jsonutils.SliceAtKey(rawMap, "intKey")
		assert.Equal(t, jsonutils.NewKeyTypeError(k, "[]any", intValue), err)
		assert.Nil(t, actual)
	})
	t.Run("key exists, is slice", func(t *testing.T) {
		actual, err := jsonutils.SliceAtKey(rawMap, "stringSliceKey")
		assert.NoError(t, err)
		assert.Equal(t, stringSliceValue, actual)
	})
}

func TestUnmarshalAtKey(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		k := "doesNotExist"
		var v myStruct
		err := jsonutils.UnmarshalAtKey(rawMap, k, &v)
		assert.Equal(t, jsonutils.NewMissingKeyError(k), err)
	})
	t.Run("key exists, unmarshal succeeds", func(t *testing.T) {
		var v myStruct
		err := jsonutils.UnmarshalAtKey(rawMap, "structKey", &v)
		assert.NoError(t, err)
		expected := myStruct{Name: "harry"}
		assert.Equal(t, expected, v)
	})
}

func TestStringsAtKey(t *testing.T) {
	t.Run("key does not exist", func(t *testing.T) {
		k := "doesNotExist"
		actual, err := jsonutils.StringsAtKey(rawMap, k)
		assert.Equal(t, jsonutils.NewMissingKeyError(k), err)
		assert.Nil(t, actual)
	})
	t.Run("key is not a slice of strings", func(t *testing.T) {
		key := "intSliceKey"
		actual, err := jsonutils.StringsAtKey(rawMap, key)
		assert.Equal(
			t,
			jsonutils.NewKeyError(key, jsonutils.NewIndexTypeError(0, "string", intSliceValue[0])),
			err,
		)
		assert.Nil(t, actual)
	})
	t.Run("key is a slice of strings", func(t *testing.T) {
		actual, err := jsonutils.StringsAtKey(rawMap, "stringSliceKey")
		assert.NoError(t, err)
		assert.Equal(t, []string{"hello", "goodbye"}, actual)
	})
}
