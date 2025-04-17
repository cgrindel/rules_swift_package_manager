package spreso

import (
	"fmt"
	"net/url"
	"path"
	"path/filepath"
	"strings"
)

// V1

// A V1PinStore represents PinStorage.V1.
// https://github.com/apple/swift-package-manager/blob/main/Sources/PackageGraph/PinsStore.swift#L230
type V1PinStore struct {
	Version int
	Object  *V1Container
}

type V1Container struct {
	Pins []*V1Pin
}

type V1Pin struct {
	Package       string
	RepositoryURL string
	State         *V1PinState
}

type V1PinState struct {
	Revision string
	Branch   string
	Version  string
}

func NewPinsFromV1PinStore(ps *V1PinStore) ([]*Pin, error) {
	pins := make([]*Pin, len(ps.Object.Pins))
	for idx, v1p := range ps.Object.Pins {
		pin, err := NewPinFromV1Pin(v1p)
		if err != nil {
			return nil, err
		}
		pins[idx] = pin
	}
	return pins, nil
}

func NewPinFromV1Pin(v1p *V1Pin) (*Pin, error) {
	pkgRef, err := NewPkgRefFromV1Pin(v1p)
	if err != nil {
		return nil, err
	}
	return &Pin{
		PkgRef: pkgRef,
		State:  NewPinStateFromV1PinState(v1p.State),
	}, nil
}

const gitExtension = ".git"

func NewPkgRefFromV1Pin(v1p *V1Pin) (*PackageReference, error) {
	var kind PkgRefKind
	var identity string
	if filepath.IsAbs(v1p.RepositoryURL) {
		kind = LocalSourceControlPkgRefKind
		identity = filepath.Base(v1p.RepositoryURL)
	} else if _, err := url.ParseRequestURI(v1p.RepositoryURL); err == nil {
		kind = RemoteSourceControlPkgRefKind
		identity = path.Base(v1p.RepositoryURL)
	} else {
		return nil, fmt.Errorf(
			"could not determine package reference kind from V1 repository URL %v",
			v1p.RepositoryURL,
		)
	}
	identity = strings.TrimSuffix(identity, gitExtension)
	return &PackageReference{
		Identity: identity,
		Kind:     kind,
		Location: v1p.RepositoryURL,
		Name:     v1p.Package,
	}, nil
}

func NewPinStateFromV1PinState(ps *V1PinState) PinState {
	if ps.Version != "" {
		return NewVersionPinState(ps.Version, ps.Revision)
	}
	if ps.Branch != "" {
		return NewBranchPinState(ps.Branch, ps.Revision)
	}
	return NewRevisionPinState(ps.Revision)
}
