package spreso

import (
	"encoding/json"
	"fmt"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/jsonutils"
)

// Pin

// A Pin is the normalized representation for a resolved Swift package.
type Pin struct {
	PkgRef *PackageReference
	State  PinState
}

// NewPinsFromResolvedPackageJSON returns the pins (resolved Swift package details) from
// `Package.resolved` JSON.
func NewPinsFromResolvedPackageJSON(b []byte) ([]*Pin, error) {
	var anyMap map[string]any
	if err := json.Unmarshal(b, &anyMap); err != nil {
		return nil, err
	}
	ver, err := jsonutils.IntAtKey(anyMap, "version")
	if err != nil {
		return nil, err
	}
	switch ver {
	case 1:
		var v1ps V1PinStore
		if err := json.Unmarshal(b, &v1ps); err != nil {
			return nil, err
		}
		return NewPinsFromV1PinStore(&v1ps)
	case 2, 3:
		var v2ps V2PinStore
		if err := json.Unmarshal(b, &v2ps); err != nil {
			return nil, err
		}
		return NewPinsFromV2PinStore(&v2ps)
	default:
		return nil, fmt.Errorf("unrecognized version %d for resolved package JSON", ver)
	}
}

// PinStateType

// A PinStateType is an enum for the representation type for the pin state.
type PinStateType int

const (
	UnknownPinStateType PinStateType = iota
	BranchPinStateType
	VersionPinStateType
	RevisionPinStateType
)

// PinState

// A PinState is the interface that all underlying pin state representations must implement.
type PinState interface {
	PinStateType() PinStateType
}

// BranchPinState

// A BranchPinState represents a source control branch.
type BranchPinState struct {
	Name     string
	Revision string
}

// NewBranchPinState returns a branch pin state.
func NewBranchPinState(name, revision string) *BranchPinState {
	return &BranchPinState{
		Name:     name,
		Revision: revision,
	}
}

// PinStateType returns the type of pin state.
func (bps *BranchPinState) PinStateType() PinStateType {
	return BranchPinStateType
}

// Commit returns the source control commit value (e.g., hash).
func (bps *BranchPinState) Commit() string {
	return bps.Revision
}

// VersionPinState

// A VersionPinState represents a semver tagged pin state.
type VersionPinState struct {
	Version  string
	Revision string
}

// NewVersionPinState returns a semver tagged pin state.
func NewVersionPinState(version, revision string) *VersionPinState {
	return &VersionPinState{
		Version:  version,
		Revision: revision,
	}
}

// PinStateType returns the type of pin state.
func (vps *VersionPinState) PinStateType() PinStateType {
	return VersionPinStateType
}

// Commit returns the source control commit value (e.g., hash).
func (vps *VersionPinState) Commit() string {
	return vps.Revision
}

// RevisionPinState

// A RevisionPinState represents a commit value/hash pin state.
type RevisionPinState struct {
	Revision string
}

// NewRevisionPinState returns a commit value pin state.
func NewRevisionPinState(revision string) *RevisionPinState {
	return &RevisionPinState{Revision: revision}
}

// PinStateType returns the type of pin state.
func (rps *RevisionPinState) PinStateType() PinStateType {
	return RevisionPinStateType
}

// Commit returns the source control commit value (e.g., hash).
func (rps *RevisionPinState) Commit() string {
	return rps.Revision
}
