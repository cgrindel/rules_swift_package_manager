package spreso

import (
	"encoding/json"
	"fmt"
)

// V2

// A V2PinStore represents PinStorage.V2.
// https://github.com/apple/swift-package-manager/blob/main/Sources/PackageGraph/PinsStore.swift#L230
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

func (vpk V2PinKind) PkgRefKind() PkgRefKind {
	switch vpk {
	case LocalSourceControlV2PinKind:
		return LocalSourceControlPkgRefKind
	case RemoteSourceControlV2PinKind:
		return RemoteSourceControlPkgRefKind
	case RegistryV2PinKind:
		return RegistryPkgRefKind
	}
	return UnknownPkgRefKind
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
	state, err := NewPinStateFromV2PinState(v2p.State)
	if err != nil {
		return nil, err
	}
	return &Pin{
		PkgRef: pkgRef,
		State:  state,
	}, nil
}

func NewPkgRefFromV2Pin(v2p *V2Pin) (*PackageReference, error) {
	return &PackageReference{
		Identity: v2p.Identity,
		Kind:     v2p.Kind.PkgRefKind(),
		Location: v2p.Location,
	}, nil
}

func NewPinStateFromV2PinState(ps *V2PinState) (PinState, error) {
	if ps.Revision == "" {
		return nil, fmt.Errorf("revision cannot be empty %+v", ps)
	}
	if ps.Version != "" {
		return NewVersionPinState(ps.Version, ps.Revision), nil
	}
	if ps.Branch != "" {
		return NewBranchPinState(ps.Branch, ps.Revision), nil
	}
	return NewRevisionPinState(ps.Revision), nil
}
