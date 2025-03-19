package spreso_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spreso"
	"github.com/stretchr/testify/assert"
)

func TestNewBranchPinState(t *testing.T) {
	branch := "branch_name"
	revision := "12345"
	actual := spreso.NewBranchPinState(branch, revision)
	expected := &spreso.BranchPinState{
		Name:     branch,
		Revision: revision,
	}
	assert.Equal(t, expected, actual)
}

func TestNewVersionPinState(t *testing.T) {
	version := "1.2.3"
	revision := "12345"
	actual := spreso.NewVersionPinState(version, revision)
	expected := &spreso.VersionPinState{
		Version:  version,
		Revision: revision,
	}
	assert.Equal(t, expected, actual)
}

func TestNewRevisionPinState(t *testing.T) {
	revision := "12345"
	actual := spreso.NewRevisionPinState(revision)
	expected := &spreso.RevisionPinState{
		Revision: revision,
	}
	assert.Equal(t, expected, actual)
}

func TestNewPinsFromResolvedPackageJSON(t *testing.T) {
	t.Run("v1", func(t *testing.T) {
		pins, err := spreso.NewPinsFromResolvedPackageJSON([]byte(v1PinStoreJSON))
		assert.NoError(t, err)
		assert.Len(t, pins, 1)
		assert.Equal(t, &swiftArgParserPin, pins[0])
	})
	t.Run("v2", func(t *testing.T) {
		pins, err := spreso.NewPinsFromResolvedPackageJSON([]byte(v2PinStoreJSON))
		assert.NoError(t, err)
		assert.Len(t, pins, 1)
		assert.Equal(t, &swiftArgParserPin, pins[0])
	})
	t.Run("unrecognized version", func(t *testing.T) {
		unrecognizedJSON := `{"version": 9}`
		pins, err := spreso.NewPinsFromResolvedPackageJSON([]byte(unrecognizedJSON))
		assert.ErrorContains(t, err, "unrecognized version 9 for resolved package JSON")
		assert.Nil(t, pins)
	})
}

var swiftArgParserPin = spreso.Pin{
	PkgRef: &spreso.PackageReference{
		Identity: "swift-argument-parser",
		Kind:     spreso.RemoteSourceControlPkgRefKind,
		Location: "https://github.com/apple/swift-argument-parser",
		Name:     "",
	},
	State: &spreso.VersionPinState{
		Version:  "1.2.0",
		Revision: "fddd1c00396eed152c45a46bea9f47b98e59301d",
	},
}

const v1PinStoreJSON = `
{
  "version": 1,
  "object": {
	"pins": [
	  {
		"repositoryURL": "https://github.com/apple/swift-argument-parser",
		"state": {
          "revision" : "fddd1c00396eed152c45a46bea9f47b98e59301d",
          "version" : "1.2.0"
		}
	  }
	]
  }
}
`

const v2PinStoreJSON = `
{
  "pins" : [
    {
      "identity" : "swift-argument-parser",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/apple/swift-argument-parser",
      "state" : {
        "revision" : "fddd1c00396eed152c45a46bea9f47b98e59301d",
        "version" : "1.2.0"
      }
    }
  ],
  "version" : 2
}
`
