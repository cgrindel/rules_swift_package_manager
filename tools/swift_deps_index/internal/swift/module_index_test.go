package swift_test

import (
	"encoding/json"
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

var fooM = swift.NewModuleFromLabelStruct(
	"Foo", "Foo", swiftpkg.SwiftSourceType, label.New("", "Sources/Foo", "Foo"), "", []string{})
var barM = swift.NewModuleFromLabelStruct(
	"Bar", "Bar", swiftpkg.SwiftSourceType, label.New("", "Sources/Bar", "Bar"), "", []string{})
var anotherRepoFooM = swift.NewModuleFromLabelStruct(
	"Foo", "Foo", swiftpkg.SwiftSourceType, label.New("another_repo", "pkg/path", "Foo"), "",
	[]string{})
var moduleIndex = make(swift.ModuleIndex)

func init() {
	moduleIndex.Add(fooM, barM, anotherRepoFooM)
}

func TestModuleIndex(t *testing.T) {
	t.Run("resolve modules", func(t *testing.T) {
		var actual *swift.Module
		tests := []struct {
			repoName   string
			moduleName string
			wval       *swift.Module
		}{
			{repoName: "", moduleName: "DoesNotExist", wval: nil},
			{repoName: "", moduleName: "Bar", wval: barM},
			{repoName: "", moduleName: "Foo", wval: fooM},
			{repoName: "another_repo", moduleName: "Foo", wval: anotherRepoFooM},
		}
		for _, tc := range tests {
			actual = moduleIndex.Resolve(tc.repoName, tc.moduleName)
			assert.Equal(t, tc.wval, actual)
		}
	})
	t.Run("modules", func(t *testing.T) {
		actual := moduleIndex.Modules()
		expected := swift.Modules{barM, fooM, anotherRepoFooM}
		assert.Equal(t, expected, actual)
	})
	t.Run("JSON roundtrip", func(t *testing.T) {
		data, err := json.Marshal(moduleIndex)
		assert.NoError(t, err)

		var mi swift.ModuleIndex
		err = json.Unmarshal(data, &mi)
		assert.NoError(t, err)
		assert.Equal(t, moduleIndex, mi)
	})
}
