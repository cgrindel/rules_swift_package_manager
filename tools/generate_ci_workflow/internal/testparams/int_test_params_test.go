package testparams_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/generate_ci_workflow/internal/testparams"
	"github.com/stretchr/testify/assert"
)

func TestNewIntTestParamsFromJSON(t *testing.T) {
	actual, err := testparams.NewIntTestParamsFromJSON([]byte(intTestParamsJSON))
	assert.NoError(t, err)
	assert.Len(t, actual, 2)
	expected := []testparams.IntTestParams{
		{Test: "@@//path:int_test", OS: "macos", RunnerOverride: "macos-15"},
		{Test: "@@//path:int_test", OS: "linux"},
	}
	assert.Equal(t, expected, actual)
}

const intTestParamsJSON = `
[
  {"test": "@@//path:int_test", "os": "macos", "bzlmod_mode": "enabled", "runner": "macos-15"},
  {"test": "@@//path:int_test", "os": "linux", "bzlmod_mode": "disabled"}
]
`

func TestRunnerOverride(t *testing.T) {
	assert.Equal(t, "macos-15", (&testparams.IntTestParams{OS: "macos", RunnerOverride: "macos-15"}).Runner())
	assert.Equal(t, "xcode-27", (&testparams.IntTestParams{OS: "macos"}).Runner())
}
