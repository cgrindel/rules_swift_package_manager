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
var di = swift.NewDependencyIndex()

func init() {
	di.AddModules(fooM, barM, anotherRepoFooM)
}

func TestDependencyIndex(t *testing.T) {
	var actual *swift.Module

	actual = di.ResolveModule("", "DoesNotExist")
	assert.Nil(t, actual)

	actual = di.ResolveModule("", "Bar")
	assert.Equal(t, barM, actual)

	actual = di.ResolveModule("", "Foo")
	assert.Equal(t, fooM, actual)

	actual = di.ResolveModule("another_repo", "Foo")
	assert.Equal(t, anotherRepoFooM, actual)
}

func TestJSONRoundtrip(t *testing.T) {
	data, err := di.JSON()
	assert.NoError(t, err)

	newMI, err := swift.NewDependencyIndexFromJSON(data)
	assert.NoError(t, err)
	assert.Equal(t, di, newMI)
}
