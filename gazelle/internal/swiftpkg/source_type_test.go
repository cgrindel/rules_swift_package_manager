package swiftpkg_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
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
