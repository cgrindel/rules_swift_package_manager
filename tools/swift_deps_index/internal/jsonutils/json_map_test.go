package jsonutils_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/jsonutils"
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
var floatValue = float64(2)
var floatValueAsInt = 2

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
	rawMap["floatKey"] = floatValue
}

func TestStringAtKey(t *testing.T) {
	tests := []struct {
		key  string
		wval string
		werr error
	}{
		{key: "doesNotExist", wval: "", werr: jsonutils.NewMissingKeyError("doesNotExist")},
		{key: "intKey", wval: "", werr: jsonutils.NewKeyTypeError("intKey", "string", intValue)},
		{key: "stringKey", wval: stringValue, werr: nil},
	}
	for _, tc := range tests {
		actual, err := jsonutils.StringAtKey(rawMap, tc.key)
		assert.Equal(t, tc.werr, err)
		assert.Equal(t, tc.wval, actual)
	}
}

func TestIntAtKey(t *testing.T) {
	tests := []struct {
		key  string
		wval int
		werr error
	}{
		{key: "doesNotExist", wval: 0, werr: jsonutils.NewMissingKeyError("doesNotExist")},
		{key: "stringKey", wval: 0, werr: jsonutils.NewKeyTypeError(
			"stringKey", "int", stringValue)},
		{key: "intKey", wval: intValue, werr: nil},
		{key: "floatKey", wval: floatValueAsInt, werr: nil},
	}
	for _, tc := range tests {
		actual, err := jsonutils.IntAtKey(rawMap, tc.key)
		assert.Equal(t, tc.werr, err)
		assert.Equal(t, tc.wval, actual)
	}
}

func TestMapAtKey(t *testing.T) {
	tests := []struct {
		key  string
		wval map[string]any
		werr error
	}{
		{key: "doesNotExist", wval: nil, werr: jsonutils.NewMissingKeyError("doesNotExist")},
		{key: "intKey", wval: nil, werr: jsonutils.NewKeyTypeError(
			"intKey", "map[string]any", intValue)},
		{key: "mapKey", wval: mapValue, werr: nil},
	}
	for _, tc := range tests {
		actual, err := jsonutils.MapAtKey(rawMap, tc.key)
		assert.Equal(t, tc.werr, err)
		assert.Equal(t, tc.wval, actual)
	}
}

func TestSliceAtKey(t *testing.T) {
	tests := []struct {
		key  string
		wval []any
		werr error
	}{
		{key: "doesNotExist", wval: nil, werr: jsonutils.NewMissingKeyError("doesNotExist")},
		{key: "intKey", wval: nil, werr: jsonutils.NewKeyTypeError("intKey", "[]any", intValue)},
		{key: "stringSliceKey", wval: stringSliceValue, werr: nil},
	}
	for _, tc := range tests {
		actual, err := jsonutils.SliceAtKey(rawMap, tc.key)
		assert.Equal(t, tc.werr, err)
		assert.Equal(t, tc.wval, actual)
	}
}

func TestUnmarshalAtKey(t *testing.T) {
	tests := []struct {
		key  string
		wval myStruct
		werr error
	}{
		{key: "doesNotExist", wval: myStruct{}, werr: jsonutils.NewMissingKeyError("doesNotExist")},
		{key: "structKey", wval: myStruct{Name: "harry"}, werr: nil},
	}
	for _, tc := range tests {
		var v myStruct
		err := jsonutils.UnmarshalAtKey(rawMap, tc.key, &v)
		assert.Equal(t, tc.werr, err)
		assert.Equal(t, tc.wval, v)
	}
}

func TestStringsAtKey(t *testing.T) {
	tests := []struct {
		key  string
		wval []string
		werr error
	}{
		{key: "doesNotExist", wval: nil, werr: jsonutils.NewMissingKeyError("doesNotExist")},
		{key: "intSliceKey", wval: nil, werr: jsonutils.NewKeyError(
			"intSliceKey", jsonutils.NewIndexTypeError(0, "string", intSliceValue[0]))},
		{key: "stringSliceKey", wval: []string{"hello", "goodbye"}, werr: nil},
	}
	for _, tc := range tests {
		actual, err := jsonutils.StringsAtKey(rawMap, tc.key)
		assert.Equal(t, tc.werr, err)
		assert.Equal(t, tc.wval, actual)
	}
}
