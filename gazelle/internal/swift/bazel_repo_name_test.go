package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestRepoNameFromIdentity(t *testing.T) {
	actual := swift.RepoNameFromIdentity("swift-argument-parser")
	assert.Equal(t, "swiftpkg_swift_argument_parser", actual)
}

func TestRepoNameFromDep(t *testing.T) {
	dep := &swiftpkg.Dependency{
		SourceControl: &swiftpkg.SourceControl{
			Identity: "cool-repo",
			Location: &swiftpkg.SourceControlLocation{
				Remote: &swiftpkg.RemoteLocation{
					URL: "https://github.com/example/cool-repo.git",
				},
			},
		},
	}
	actual, err := swift.RepoNameFromDep(dep)
	assert.NoError(t, err)
	assert.Equal(t, "swiftpkg_cool_repo", actual)
}
