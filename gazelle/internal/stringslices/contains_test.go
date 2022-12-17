package stringslices_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/stringslices"
	"github.com/stretchr/testify/assert"
)

func TestContains(t *testing.T) {
	values := []string{"Foo", "Bar"}
	assert.True(t, stringslices.Contains(values, "Foo"))
	assert.True(t, stringslices.Contains(values, "Bar"))
	assert.False(t, stringslices.Contains(values, "Chicken"))
}

func TestSortedContains(t *testing.T) {
	values := []string{"apple", "mango", "zebra"}
	assert.True(t, stringslices.SortedContains(values, "apple"))
	assert.True(t, stringslices.SortedContains(values, "mango"))
	assert.True(t, stringslices.SortedContains(values, "zebra"))
	assert.False(t, stringslices.SortedContains(values, "doesNotExist"))
	assert.False(t, stringslices.SortedContains(values, "zoo"))
}
