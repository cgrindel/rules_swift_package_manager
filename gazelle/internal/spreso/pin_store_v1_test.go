package spreso_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/stretchr/testify/assert"
)

func TestPkgRefKindFromV1RepoURL(t *testing.T) {
	t.Run("fully qualified URI", func(t *testing.T) {
		actual, err := spreso.PkgRefKindFromV1RepoURL("https://github.com/apple/swift-argument-parser")
		assert.NoError(t, err)
		assert.Equal(t, spreso.RemoteSourceControlPkgRefKind, actual)
	})
	t.Run("absolute path", func(t *testing.T) {
		actual, err := spreso.PkgRefKindFromV1RepoURL("/path/to/repo")
		assert.NoError(t, err)
		assert.Equal(t, spreso.LocalSourceControlPkgRefKind, actual)
	})
	t.Run("unrecognized", func(t *testing.T) {
		actual, err := spreso.PkgRefKindFromV1RepoURL("relative/path/to/repo")
		assert.ErrorContains(t, err, "could not determine package reference kind from repository URL")
		assert.Equal(t, spreso.UnknownPkgRefKind, actual)
	})
}

func TestNewPinFromV1Pin(t *testing.T) {
	t.Error("IMPLEMENT ME!")
}

func TestNewPinsFromV1PinStore(t *testing.T) {
	t.Error("IMPLEMENT ME!")
}
