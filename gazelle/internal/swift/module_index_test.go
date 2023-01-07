package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

var fooM = swift.NewModule("Foo", label.New("", "Sources/Foo", "Foo"))
var barM = swift.NewModule("Bar", label.New("", "Sources/Bar", "Bar"))
var anotherRepoFooM = swift.NewModule("Foo", label.New("another_repo", "pkg/path", "Foo"))
var moduleIndex = make(swift.ModuleIndex)

func init() {
	moduleIndex.Add(fooM, barM, anotherRepoFooM)
}

func TestModuleIndex(t *testing.T) {
	var actual *swift.Module

	actual = moduleIndex.Resolve("", "DoesNotExist")
	assert.Nil(t, actual)

	actual = moduleIndex.Resolve("", "Bar")
	assert.Equal(t, barM, actual)

	actual = moduleIndex.Resolve("", "Foo")
	assert.Equal(t, fooM, actual)

	actual = moduleIndex.Resolve("another_repo", "Foo")
	assert.Equal(t, anotherRepoFooM, actual)
}
