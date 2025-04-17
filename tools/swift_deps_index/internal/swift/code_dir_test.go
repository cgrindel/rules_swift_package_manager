package swift_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/stretchr/testify/assert"
)

const pkgDir = "/path/to/pkg"
const buildDir = "/path/to/build"

func TestCodeDirForRemotePackage(t *testing.T) {
	tests := []struct {
		url  string
		wval string
	}{
		{
			url:  "https://github.com/nicklockwood/SwiftFormat",
			wval: "/path/to/build/checkouts/SwiftFormat",
		},
		{
			url:  "https://github.com/nicklockwood/SwiftFormat.git",
			wval: "/path/to/build/checkouts/SwiftFormat",
		},
		{
			url:  "https://github.com/nicklockwood/SwiftFormat.swift",
			wval: "/path/to/build/checkouts/SwiftFormat.swift",
		},
	}
	for _, tc := range tests {
		actual := swift.CodeDirForRemotePackage(buildDir, tc.url)
		assert.Equal(t, tc.wval, actual)
	}
}

func TestCodeDirForLocalPackage(t *testing.T) {
	tests := []struct {
		pkgPath string
		wval    string
	}{
		{pkgPath: "/path/to/local_pkg", wval: "/path/to/local_pkg"},
		{pkgPath: "../local_pkg", wval: "/path/to/local_pkg"},
	}
	for _, tc := range tests {
		actual := swift.CodeDirForLocalPackage(pkgDir, tc.pkgPath)
		assert.Equal(t, tc.wval, actual)
	}
}
