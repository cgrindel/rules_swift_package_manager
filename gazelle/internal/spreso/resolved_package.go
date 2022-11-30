package spreso

type ResolvedPackage struct {
	Version string
	Pins    []Pin
}

type PkgRefKind int

const (
	UnknownPkgRefKind PkgRefKind = iota
	RootPkgRefKind
	FileSystemPkgRefKind
	LocalSourceControlPkgRefKind
	RemoteSourceControlPkgRefKind
	RegistryPkgRefKind
)

type PackageReference struct {
	Identity string
	Kind     PkgRefKind
	Location string
	Name     string
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

// Represents PinsStore.Pin from Swift package manager.
// Melding of a PackageReference and PinState (enum)
type Pin struct {
	PackageReference
	State PinState
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
