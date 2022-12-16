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
var mi = swift.NewModuleIndex()

func init() {
	mi.AddModules(fooM, barM, anotherRepoFooM)
}

func TestModuleIndex(t *testing.T) {
	var actual *swift.Module

	actual = mi.Resolve("", "DoesNotExist")
	assert.Nil(t, actual)

	actual = mi.Resolve("", "Bar")
	assert.Equal(t, barM, actual)

	actual = mi.Resolve("", "Foo")
	assert.Equal(t, fooM, actual)

	actual = mi.Resolve("another_repo", "Foo")
	assert.Equal(t, anotherRepoFooM, actual)
}

func TestJSONRoundtrip(t *testing.T) {
	data, err := mi.JSON()
	assert.NoError(t, err)

	newMI, err := swift.NewModuleIndexFromJSON(data)
	assert.NoError(t, err)
	assert.Equal(t, mi, newMI)
}
