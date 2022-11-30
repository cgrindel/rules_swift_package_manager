package spreso

type Pin struct {
	PkgRef PackageReference
	State  PinState
}

type PinStateType int

const (
	UnknownPinStateType PinStateType = iota
	BranchPinStateType
	VersionPinStateType
	RevisionPinStateType
)

type PinState interface {
	PinStateType() PinStateType
}

type BranchPinState struct {
	Name     string
	Revision string
}

func (bps *BranchPinState) PinStateType() PinStateType {
	return BranchPinStateType
}

type VersionPinState struct {
	Version  string
	Revision string
}

func (vps *VersionPinState) PinStateType() PinStateType {
	return VersionPinStateType
}

type RevisionPinState struct {
	Revision string
}

func (rps *RevisionPinState) PinStateType() PinStateType {
	return RevisionPinStateType
}
