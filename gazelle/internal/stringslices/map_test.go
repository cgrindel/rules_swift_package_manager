package stringslices_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/stringslices"
	"github.com/stretchr/testify/assert"
)

func TestMap(t *testing.T) {
	mapFn := func(value string) string {
		return value + "a"
	}
	t.Run("empty values", func(t *testing.T) {
		actual := stringslices.Map([]string{}, mapFn)
		expected := []string{}
		assert.Equal(t, expected, actual)
	})
	t.Run("non-empty values", func(t *testing.T) {
		actual := stringslices.Map([]string{"x", "y", "z"}, mapFn)
		expected := []string{"xa", "ya", "za"}
		assert.Equal(t, expected, actual)
	})
}
