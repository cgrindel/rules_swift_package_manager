package spreso

// Pin

type Pin struct {
	PkgRef *PackageReference
	State  PinState
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
