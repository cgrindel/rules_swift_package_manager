package testparams_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/tools/generate_ci_workflow/internal/example"
	"github.com/stretchr/testify/assert"
)

func TestNewExamplesFromJSON(t *testing.T) {
	examples, err := example.NewExamplesFromJSON([]byte(intTestParamsJSON))
	assert.NoError(t, err)
	assert.Len(t, examples, 2)
}

const intTestParamsJSON = `
[
  {"test": "@@//path:int_test", "os": "macos", "enable_bzlmod": true},
  {"test": "@@//path:int_test", "os": "linux", "enable_bzlmod": true}
]
`
