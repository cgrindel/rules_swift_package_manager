package spreso

import (
	"encoding/json"
	"fmt"

 	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonutils"
)

// Pin

type Pin struct {
	PkgRef *PackageReference
	State  PinState
}

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
	case 2:
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

type PinStateType int

const (
	UnknownPinStateType PinStateType = iota
	BranchPinStateType
	VersionPinStateType
	RevisionPinStateType
)

// PinState

type PinState interface {
	PinStateType() PinStateType
}

// BranchPinState

type BranchPinState struct {
	Name     string
	Revision string
}

func NewBranchPinState(name, revision string) *BranchPinState {
	return &BranchPinState{
		Name:     name,
		Revision: revision,
	}
}

func (bps *BranchPinState) PinStateType() PinStateType {
	return BranchPinStateType
}

func (bps *BranchPinState) Commit() string {
	return bps.Revision
}

// VersionPinState

type VersionPinState struct {
	Version  string
	Revision string
}

func NewVersionPinState(version, revision string) *VersionPinState {
	return &VersionPinState{
		Version:  version,
		Revision: revision,
	}
}

func (vps *VersionPinState) PinStateType() PinStateType {
	return VersionPinStateType
}

func (vps *VersionPinState) Commit() string {
	return vps.Revision
}

// RevisionPinState

type RevisionPinState struct {
	Revision string
}

func NewRevisionPinState(revision string) *RevisionPinState {
	return &RevisionPinState{Revision: revision}
}

func (rps *RevisionPinState) PinStateType() PinStateType {
	return RevisionPinStateType
}

func (rps *RevisionPinState) Commit() string {
	return rps.Revision
}
