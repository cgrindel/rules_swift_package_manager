package spreso

// V1

// Maps to PinStorage.V1
// https://github.com/apple/swift-package-manager/blob/main/Sources/PackageGraph/PinsStore.swift#L230
type V1PinStore struct {
	Version int
	Object  V1Container
}

type V1Container struct {
	Pins []V1Pin
}

type V1Pin struct {
	Package       string
	RepositoryURL string
	State         V1PinState
}

type V1PinState struct {
	Revision string
	Branch   string
	Version  string
}

// func NewPinsFromV1PinStore(ps V1PinStore) []*Pin {
// 	pins := make([]*Pin, len(ps.Object.Pins))
// 	for idx, psp := range ps.Object.Pins {
// 		pin := Pin{}
// 		pin.PkgRef = &PackageReference{
// 			Identity: psp.RepositoryURL,
// 			Kind:
// 			Location string
// 			Name     string
// 		}
// 	}
// }

// V2

type V2PinStore struct {
	Version int
	Pins    []V2Pin
}

type V2Pin struct {
	Identity string
	Kind     V2Kind
	Location string
	State    V2PinState
}

type V2Kind int

const (
	UnknownV2Kind V2Kind = iota
	LocalSourceControlV2Kind
	RemoteSourceControlV2Kind
	RegistryV2Kind
)

type V2PinState struct {
	Version  string
	Branch   string
	Revision string
}
