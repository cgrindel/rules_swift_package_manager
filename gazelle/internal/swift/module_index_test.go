package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestModuleIndex(t *testing.T) {
	mi := swift.NewModuleIndex()
	fooM := swift.NewModule("Foo", label.New("", "Sources/Foo", "Foo"))
	barM := swift.NewModule("Bar", label.New("", "Sources/Bar", "Bar"))
	anotherRepoFooM := swift.NewModule("Foo", label.New("another_repo", "pkg/path", "Foo"))
	mi.AddModules(fooM, barM, anotherRepoFooM)

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
