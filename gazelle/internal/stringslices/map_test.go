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
	tests := []struct {
		values []string
		wval   []string
	}{
		{values: []string{}, wval: []string{}},
		{values: []string{"x", "y", "z"}, wval: []string{"xa", "ya", "za"}},
	}
	for _, tc := range tests {
		actual := stringslices.Map(tc.values, mapFn)
		assert.Equal(t, tc.wval, actual)
	}
}
