package spreso

import "encoding/json"

// V2

type V2PinStore struct {
	Version int
	Pins    []*V2Pin
}

type V2Pin struct {
	Identity string
	Kind     V2PinKind
	Location string
	State    *V2PinState
}

type V2PinKind int

const (
	UnknownV2PinKind V2PinKind = iota
	LocalSourceControlV2PinKind
	RemoteSourceControlV2PinKind
	RegistryV2PinKind
)

func (vpk *V2PinKind) UnmarshalJSON(b []byte) error {
	var jsonVal string
	if err := json.Unmarshal(b, &jsonVal); err != nil {
		return err
	}
	switch jsonVal {
	case "localSourceControl":
		*vpk = LocalSourceControlV2PinKind
	case "remoteSourceControl":
		*vpk = RemoteSourceControlV2PinKind
	case "registry":
		*vpk = RegistryV2PinKind
	}
	return nil
}

type V2PinState struct {
	Version  string
	Branch   string
	Revision string
}

func NewPinsFromV2PinStore(ps *V2PinStore) ([]*Pin, error) {
	pins := make([]*Pin, len(ps.Pins))
	for idx, v2p := range ps.Pins {
		pin, err := NewPinFromV2Pin(v2p)
		if err != nil {
			return nil, err
		}
		pins[idx] = pin
	}
	return pins, nil
}

func NewPinFromV2Pin(v2p *V2Pin) (*Pin, error) {
	pkgRef, err := NewPkgRefFromV2Pin(v2p)
	if err != nil {
		return nil, err
	}
	return &Pin{
		PkgRef: pkgRef,
		State:  NewPinStateFromV2PinState(v2p.State),
	}, nil
}

func NewPkgRefFromV2Pin(v2p *V2Pin) (*PackageReference, error) {
	var kind PkgRefKind
	switch v2p.Kind {
	case LocalSourceControlV2PinKind:
		kind = LocalSourceControlPkgRefKind
	case RemoteSourceControlV2PinKind:
		kind = RemoteSourceControlPkgRefKind
	case RegistryV2PinKind:
		kind = RegistryPkgRefKind
	}
	return &PackageReference{
		Identity: v2p.Identity,
		Kind:     kind,
		Location: v2p.Location,
	}, nil
}

func NewPinStateFromV2PinState(ps *V2PinState) PinState {
	if ps.Version != "" {
		return NewVersionPinState(ps.Version, ps.Revision)
	}
	if ps.Branch != "" {
		return NewBranchPinState(ps.Branch, ps.Revision)
	}
	return NewRevisionPinState(ps.Revision)
}
