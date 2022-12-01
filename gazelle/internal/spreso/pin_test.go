package spreso_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
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
		t.Error("IMPLEMENT ME!")
	})
	t.Run("v2", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
	})
	t.Run("unrecognized version", func(t *testing.T) {
		t.Error("IMPLEMENT ME!")
	})
}
