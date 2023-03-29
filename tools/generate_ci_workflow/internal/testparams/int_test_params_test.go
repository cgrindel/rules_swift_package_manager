package testparams_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/tools/generate_ci_workflow/internal/testparams"
	"github.com/stretchr/testify/assert"
)

func TestNewIntTestParamsFromJSON(t *testing.T) {
	actual, err := testparams.NewIntTestParamsFromJSON([]byte(intTestParamsJSON))
	assert.NoError(t, err)
	assert.Len(t, actual, 2)
	expected := []testparams.IntTestParams{
		{Test: "@@//path:int_test", OS: "macos", BzlmodMode: "enabled"},
		{Test: "@@//path:int_test", OS: "linux", BzlmodMode: "disabled"},
	}
	assert.Equal(t, expected, actual)
}

const intTestParamsJSON = `
[
  {"test": "@@//path:int_test", "os": "macos", "bzlmod_mode": "enabled"},
  {"test": "@@//path:int_test", "os": "linux", "bzlmod_mode": "disabled"}
]
`
