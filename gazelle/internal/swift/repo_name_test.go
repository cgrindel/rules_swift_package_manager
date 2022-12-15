package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestRepoNameFromURL(t *testing.T) {
	actual, err := swift.RepoNameFromURL("https://github.com/nicklockwood/SwiftFormat.git")
	assert.NoError(t, err)
	assert.Equal(t, "nicklockwood_SwiftFormat", actual)

	actual, err = swift.RepoNameFromURL("https://github.com/nicklockwood/SwiftFormat")
	assert.NoError(t, err)
	assert.Equal(t, "nicklockwood_SwiftFormat", actual)

	actual, err = swift.RepoNameFromURL("")
	assert.ErrorContains(t, err, "URL cannot be empty string")
	assert.Equal(t, "", actual)
}

func TestRepoNameFromStr(t *testing.T) {
	actual := swift.RepoNameFromStr("swift-argument-parser")
	assert.Equal(t, "swift_argument_parser", actual)
}

func TestRepoNameFromPin(t *testing.T) {
	t.Run("pin is remoteSourceControl", func(t *testing.T) {
		p := &spreso.Pin{
			PkgRef: &spreso.PackageReference{
				Kind:     spreso.RemoteSourceControlPkgRefKind,
				Location: "https://github.com/apple/swift-argument-parser",
				Identity: "swift-argument-parser",
			},
		}
		actual, err := swift.RepoNameFromPin(p)
		assert.NoError(t, err)
		assert.Equal(t, "apple_swift_argument_parser", actual)
	})
	t.Run("pin is not remoteSourceControl", func(t *testing.T) {
		p := &spreso.Pin{
			PkgRef: &spreso.PackageReference{
				Kind:     spreso.LocalSourceControlPkgRefKind,
				Location: "/path/to/repo",
				Identity: "swift-argument-parser",
			},
		}
		actual, err := swift.RepoNameFromPin(p)
		assert.NoError(t, err)
		assert.Equal(t, "swift_argument_parser", actual)
	})
}

func TestRepoNameFromDep(t *testing.T) {
	t.Error("IMPLEMENT ME!")
}
