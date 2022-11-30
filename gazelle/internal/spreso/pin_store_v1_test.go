package spreso_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/stretchr/testify/assert"
)

// func TestPkgRefKindFromV1RepoURL(t *testing.T) {
// 	t.Run("fully qualified URI", func(t *testing.T) {
// 		actual, err := spreso.PkgRefKindFromV1RepoURL("https://github.com/apple/swift-argument-parser")
// 		assert.NoError(t, err)
// 		assert.Equal(t, spreso.RemoteSourceControlPkgRefKind, actual)
// 	})
// 	t.Run("absolute path", func(t *testing.T) {
// 		actual, err := spreso.PkgRefKindFromV1RepoURL("/path/to/repo")
// 		assert.NoError(t, err)
// 		assert.Equal(t, spreso.LocalSourceControlPkgRefKind, actual)
// 	})
// 	t.Run("unrecognized", func(t *testing.T) {
// 		actual, err := spreso.PkgRefKindFromV1RepoURL("relative/path/to/repo")
// 		assert.ErrorContains(t, err, "could not determine package reference kind from repository URL")
// 		assert.Equal(t, spreso.UnknownPkgRefKind, actual)
// 	})
// }

func TestPkgRefFromV1Pin(t *testing.T) {
	pkg := "package"
	t.Run("fully qualified URI", func(t *testing.T) {
		url := "https://github.com/apple/swift-argument-parser.git"
		v1p := &spreso.V1Pin{
			Package:       pkg,
			RepositoryURL: url,
		}
		actual, err := spreso.NewPkgRefFromV1Pin(v1p)
		assert.NoError(t, err)
		expected := &spreso.PackageReference{
			Identity: "swift-argument-parser",
			Kind:     spreso.RemoteSourceControlPkgRefKind,
			Location: url,
			Name:     pkg,
		}
		assert.Equal(t, expected, actual)
	})
	t.Run("absolute path", func(t *testing.T) {
		url := "/path/to/swift-argument-parser"
		v1p := &spreso.V1Pin{
			Package:       pkg,
			RepositoryURL: url,
		}
		actual, err := spreso.NewPkgRefFromV1Pin(v1p)
		assert.NoError(t, err)
		expected := &spreso.PackageReference{
			Identity: "swift-argument-parser",
			Kind:     spreso.LocalSourceControlPkgRefKind,
			Location: url,
			Name:     pkg,
		}
		assert.Equal(t, expected, actual)
	})
	t.Run("unrecognized", func(t *testing.T) {
		url := "relative/path/to/swift-argument-parser"
		v1p := &spreso.V1Pin{
			Package:       pkg,
			RepositoryURL: url,
		}
		actual, err := spreso.NewPkgRefFromV1Pin(v1p)
		assert.ErrorContains(t, err,
			"could not determine package reference kind from V1 repository URL")
		assert.Nil(t, actual)
	})
}

func TestNewPinFromV1Pin(t *testing.T) {
	t.Error("IMPLEMENT ME!")
}

func TestNewPinsFromV1PinStore(t *testing.T) {
	t.Error("IMPLEMENT ME!")
}
