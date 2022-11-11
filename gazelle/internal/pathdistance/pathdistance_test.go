package pathdistance_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/pathdistance"
	"github.com/stretchr/testify/assert"
)

func TestGetPathAtDistance(t *testing.T) {
	t.Run("path is empty", func(t *testing.T) {
		actual := pathdistance.PathAt("", 3)
		assert.Equal(t, "", actual)
	})
	t.Run("distance is greater than or equal to 0", func(t *testing.T) {
		actual := pathdistance.PathAt("foo/bar/hello", 0)
		assert.Equal(t, "foo/bar/hello", actual)

		actual = pathdistance.PathAt("foo/bar/hello", 1)
		assert.Equal(t, "foo/bar", actual)

		actual = pathdistance.PathAt("foo/bar/hello", 2)
		assert.Equal(t, "foo", actual)
	})
	t.Run("distance is greater than path parts length", func(t *testing.T) {
		actual := pathdistance.PathAt("foo/bar/hello", 10)
		assert.Equal(t, "", actual)
	})
}

func TestDistanceFromPath(t *testing.T) {
	values := []string{"foo"}
	t.Run("path is empty", func(t *testing.T) {
		actual := pathdistance.DistanceFrom(values, "")
		assert.Equal(t, -1, actual)
	})
	t.Run("no values found in the path", func(t *testing.T) {
		actual := pathdistance.DistanceFrom(values, "chicken/bar/hello")
		assert.Equal(t, -1, actual)
	})
	t.Run("current directory is a match", func(t *testing.T) {
		actual := pathdistance.DistanceFrom(values, "chicken/bar/foo")
		assert.Equal(t, 0, actual)
	})
	t.Run("parent directory is a match", func(t *testing.T) {
		actual := pathdistance.DistanceFrom(values, "chicken/foo/hello")
		assert.Equal(t, 1, actual)
	})
	t.Run("grandparent directory is a match", func(t *testing.T) {
		actual := pathdistance.DistanceFrom(values, "foo/bar/hello")
		assert.Equal(t, 2, actual)
	})
}
