package swiftpkg_test

import (
	"encoding/json"
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestNewSourceType(t *testing.T) {
	tests := []struct {
		name  string
		mtype swiftpkg.ModuleType
		paths []string
		exp   swiftpkg.SourceType
	}{
		{
			name:  "swift",
			mtype: swiftpkg.SwiftModuleType,
			paths: []string{"path/to/File.swift"},
			exp:   swiftpkg.SwiftSourceType,
		},
		{
			name:  "clang",
			mtype: swiftpkg.ClangModuleType,
			paths: []string{"path/to/file.c"},
			exp:   swiftpkg.ClangSourceType,
		},
		{
			name:  "objc .m",
			mtype: swiftpkg.ClangModuleType,
			paths: []string{"path/to/file.m"},
			exp:   swiftpkg.ObjcSourceType,
		},
		{
			name:  "objc .mm",
			mtype: swiftpkg.ClangModuleType,
			paths: []string{"path/to/file.mm"},
			exp:   swiftpkg.ObjcSourceType,
		},
		{
			name:  "unknown",
			mtype: swiftpkg.UnknownModuleType,
			paths: nil,
			exp:   swiftpkg.UnknownSourceType,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			actual := swiftpkg.NewSourceType(test.mtype, test.paths)
			assert.Equal(t, test.exp, actual)
		})
	}
}

func TestSourceTypeJSONRoundtrip(t *testing.T) {
	tests := []struct {
		name string
		val  swiftpkg.SourceType
	}{
		{name: "unknown", val: swiftpkg.UnknownSourceType},
		{name: "swift", val: swiftpkg.SwiftSourceType},
		{name: "clang", val: swiftpkg.ClangSourceType},
		{name: "objc", val: swiftpkg.ObjcSourceType},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			b, err := json.Marshal(test.val)
			assert.NoError(t, err, "marshal value")
			var actual swiftpkg.SourceType
			err = json.Unmarshal(b, &actual)
			assert.NoError(t, err, "unmarshal value")
			assert.Equal(t, test.val, actual)
		})
	}
}
