package spreso

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
