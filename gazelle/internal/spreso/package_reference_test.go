package spreso_test

import (
	"encoding/json"
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/stretchr/testify/assert"
)

func strToPkgRefKind(val string) (spreso.PkgRefKind, error) {
	kind := spreso.UnknownPkgRefKind
	jsonVal, err := json.Marshal(val)
	if err != nil {
		return kind, err
	}
	if err := kind.UnmarshalJSON(jsonVal); err != nil {
		return kind, err
	}
	return kind, nil
}

func TestPkgRefKindUnmarshalJSON(t *testing.T) {
	t.Run("root", func(t *testing.T) {
		actual, err := strToPkgRefKind("root")
		assert.NoError(t, err)
		assert.Equal(t, spreso.RootPkgRefKind, actual)
	})
	t.Run("fileSystem", func(t *testing.T) {
		actual, err := strToPkgRefKind("fileSystem")
		assert.NoError(t, err)
		assert.Equal(t, spreso.FileSystemPkgRefKind, actual)
	})
	t.Run("localSourceControl", func(t *testing.T) {
		actual, err := strToPkgRefKind("localSourceControl")
		assert.NoError(t, err)
		assert.Equal(t, spreso.LocalSourceControlPkgRefKind, actual)
	})
	t.Run("remoteSourceControl", func(t *testing.T) {
		actual, err := strToPkgRefKind("remoteSourceControl")
		assert.NoError(t, err)
		assert.Equal(t, spreso.RemoteSourceControlPkgRefKind, actual)
	})
	t.Run("registry", func(t *testing.T) {
		actual, err := strToPkgRefKind("registry")
		assert.NoError(t, err)
		assert.Equal(t, spreso.RegistryPkgRefKind, actual)
	})
}
