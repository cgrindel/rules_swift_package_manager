package example_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/tools/generate_ci_workflow/internal/example"
	"github.com/stretchr/testify/assert"
)

func TestNewExamplesFromJSON(t *testing.T) {
	examples, err := example.NewExamplesFromJSON([]byte(examplesJSON))
	assert.NoError(t, err)
	assert.Len(t, examples, 2)
}

const examplesJSON = `
[
  {"name": "foo_example", "oss": ["macos", "linux"], "versions": [".bazelversion", "5_4_0"], "enable_bzlmods": [true, false]},
  {"name": "bar_example", "oss": ["macos"], "versions": [".bazelversion"], "enable_bzlmods": [true]}
]
`
