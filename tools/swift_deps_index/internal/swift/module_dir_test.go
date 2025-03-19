package swift_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestModuleRootDir(t *testing.T) {
	tests := []struct {
		msg       string
		cModPaths []string
		path      string
		wval      string
	}{
		{
			msg:  "path is module, Sources at root",
			path: "Sources/Chicken",
			wval: "Sources/Chicken",
		},
		{
			msg:  "path is module, Sources in sub-dir",
			path: "foo/Source/Chicken",
			wval: "foo/Source/Chicken",
		},
		{
			msg:  "path is under a module path",
			path: "foo/Sources/Chicken/Panther",
			wval: "foo/Sources/Chicken",
		},
		{
			msg:  "path is under a test module path",
			path: "Tests/ChickenTests/PantherTests",
			wval: "Tests/ChickenTests",
		},
		{
			msg:  "path does not contain module directory",
			path: "foo/Chicken",
			wval: "foo/Chicken",
		},
		{
			msg:       "path is module, config module paths provided",
			cModPaths: []string{"foo", "bar"},
			path:      "Sources/Chicken",
			wval:      "Sources/Chicken",
		},
		{
			msg:       "path is under config module path",
			cModPaths: []string{"foo", "bar"},
			path:      "foo/Chicken",
			wval:      "foo",
		},
		{
			msg:       "path is not a child of standard module dir, not in config module paths",
			cModPaths: []string{"bar"},
			path:      "foo/Chicken",
			wval:      "foo/Chicken",
		},
		{
			msg:       "module path is set to root of the workspace",
			cModPaths: []string{""},
			path:      "foo/Chicken",
			wval:      "",
		},
	}
	for _, tc := range tests {
		actual := swift.ModuleDir(tc.cModPaths, tc.path)
		assert.Equal(t, tc.wval, actual, tc.msg)
	}
}
