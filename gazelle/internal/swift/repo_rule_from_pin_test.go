package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestRepoRuleFromPin(t *testing.T) {
	remote := "https://github.com/apple/swift-argument-parser"
	version := "1.2.3"
	revision := "12345"
	p := &spreso.Pin{
		PkgRef: &spreso.PackageReference{
			Location: remote,
		},
		State: &spreso.VersionPinState{
			Version:  version,
			Revision: revision,
		},
	}
	actual, err := swift.RepoRuleFromPin(p)
	assert.NoError(t, err)
	assert.Equal(t, swift.SwiftPkgRuleKind, actual.Kind())
	expectedName, err := swift.RepoNameFromPin(p)
	assert.NoError(t, err)
	assert.Equal(t, expectedName, actual.Name())
	assert.Equal(t, remote, actual.AttrString("remote"))
	assert.Equal(t, revision, actual.AttrString("commit"))
	assert.Len(t, actual.Comments(), 1)
	assert.Contains(t, actual.Comments()[0], "# version: 1.2.3")
}
