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

func (bps *BranchPinState) PinStateType() PinStateType {
	return BranchPinStateType
}

// VersionPinState

type VersionPinState struct {
	Version  string
	Revision string
}

func (vps *VersionPinState) PinStateType() PinStateType {
	return VersionPinStateType
}

// RevisionPinState

type RevisionPinState struct {
	Revision string
}

func (rps *RevisionPinState) PinStateType() PinStateType {
	return RevisionPinStateType
}
