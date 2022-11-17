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
