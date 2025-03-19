package spreso_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spreso"
	"github.com/stretchr/testify/assert"
)

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
	t.Run("version pin state", func(t *testing.T) {
		version := "1.2.3"
		revision := "12345"
		ps := &spreso.V1PinState{
			Version:  version,
			Revision: revision,
		}
		actual := spreso.NewPinStateFromV1PinState(ps)
		assert.NotNil(t, actual)
		if vps, ok := actual.(*spreso.VersionPinState); ok {
			assert.Equal(t, spreso.NewVersionPinState(version, revision), vps)
		} else {
			assert.Fail(t, "Expected to be VersionPinState")
		}
	})
	t.Run("branch pin state", func(t *testing.T) {
		branch := "branch_name"
		revision := "12345"
		ps := &spreso.V1PinState{
			Branch:   branch,
			Revision: revision,
		}
		actual := spreso.NewPinStateFromV1PinState(ps)
		assert.NotNil(t, actual)
		if bps, ok := actual.(*spreso.BranchPinState); ok {
			assert.Equal(t, spreso.NewBranchPinState(branch, revision), bps)
		} else {
			assert.Fail(t, "Expected to be BranchPinState")
		}
	})
	t.Run("revision pin state", func(t *testing.T) {
		revision := "12345"
		ps := &spreso.V1PinState{
			Revision: revision,
		}
		actual := spreso.NewPinStateFromV1PinState(ps)
		assert.NotNil(t, actual)
		if rps, ok := actual.(*spreso.RevisionPinState); ok {
			assert.Equal(t, spreso.NewRevisionPinState(revision), rps)
		} else {
			assert.Fail(t, "Expected to be RevisionPinState")
		}
	})
}

func TestNewPinsFromV1PinStore(t *testing.T) {
	ps := &spreso.V1PinStore{
		Version: 1,
		Object: &spreso.V1Container{
			Pins: []*spreso.V1Pin{
				{
					RepositoryURL: "https://github.com/apple/swift-argument-parser.git",
					State:         &spreso.V1PinState{Version: "1.2.3", Revision: "12345"},
				},
				{
					RepositoryURL: "/path/to/local_repo",
					State:         &spreso.V1PinState{Branch: "branch_name", Revision: "12345"},
				},
			},
		},
	}
	pins, err := spreso.NewPinsFromV1PinStore(ps)
	assert.NoError(t, err)
	assert.Len(t, pins, 2)
	assert.Equal(t, "swift-argument-parser", pins[0].PkgRef.Identity)
	assert.Equal(t, "local_repo", pins[1].PkgRef.Identity)
}
