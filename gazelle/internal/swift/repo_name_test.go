package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestRepoName(t *testing.T) {
	actual, err := swift.RepoName("https://github.com/nicklockwood/SwiftFormat.git")
	assert.NoError(t, err)
	assert.Equal(t, "nicklockwood_SwiftFormat", actual)

	actual, err = swift.RepoName("https://github.com/nicklockwood/SwiftFormat")
	assert.NoError(t, err)
	assert.Equal(t, "nicklockwood_SwiftFormat", actual)

	actual, err = swift.RepoName("")
	assert.ErrorContains(t, err, "URL cannot be empty string")
	assert.Equal(t, "", actual)
}
