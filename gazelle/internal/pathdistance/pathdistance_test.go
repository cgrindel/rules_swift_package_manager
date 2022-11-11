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
	t.Run("distance is 0", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
	})
	t.Run("distance is greater than 0", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
	})
}

func TestDistanceFromPath(t *testing.T) {
	t.Run("path is empty", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
	})
	t.Run("no values found in the path", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
	})
	t.Run("current directory is a match", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
	})
	t.Run("parent directory is a match", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
	})
	t.Run("grandparent directory is a match", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
	})
}
