package swift_test

import (
	"encoding/json"
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

var fooM = swift.NewModuleFromLabelStruct("Foo", "Foo", label.New("", "Sources/Foo", "Foo"))
var barM = swift.NewModuleFromLabelStruct("Bar", "Bar", label.New("", "Sources/Bar", "Bar"))
var anotherRepoFooM = swift.NewModuleFromLabelStruct(
	"Foo", "Foo", label.New("another_repo", "pkg/path", "Foo"))
var moduleIndex = make(swift.ModuleIndex)

func init() {
	moduleIndex.Add(fooM, barM, anotherRepoFooM)
}

func TestModuleIndex(t *testing.T) {
	t.Run("resolve modules", func(t *testing.T) {
		var actual *swift.Module

		actual = moduleIndex.Resolve("", "DoesNotExist")
		assert.Nil(t, actual)

		actual = moduleIndex.Resolve("", "Bar")
		assert.Equal(t, barM, actual)

		actual = moduleIndex.Resolve("", "Foo")
		assert.Equal(t, fooM, actual)

		actual = moduleIndex.Resolve("another_repo", "Foo")
		assert.Equal(t, anotherRepoFooM, actual)
	})
	t.Run("modules", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
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
