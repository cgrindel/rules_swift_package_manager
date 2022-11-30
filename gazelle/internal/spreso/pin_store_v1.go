package spreso

import (
	"fmt"
	"net/url"
	"path/filepath"
)

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

func NewPinsFromV1PinStore(ps V1PinStore) ([]*Pin, error) {
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

func NewPinFromV1Pin(psp V1Pin) (*Pin, error) {
	kind, err := PkgRefKindFromV1RepoURL(psp.RepositoryURL)
	if err != nil {
		return nil, err
	}
	return &Pin{
		PkgRef: &PackageReference{
			Identity: identityFromV1RepoURL(psp.RepositoryURL),
			Kind:     kind,
			Location: psp.RepositoryURL,
			Name:     psp.Package,
		},
		State: newPinStateFromV1PinState(psp.State),
	}, nil
}

func PkgRefKindFromV1RepoURL(repoURL string) (PkgRefKind, error) {
	if filepath.IsAbs(repoURL) {
		return LocalSourceControlPkgRefKind, nil
	}
	if _, err := url.ParseRequestURI(repoURL); err == nil {
		return RemoteSourceControlPkgRefKind, nil
	}
	return UnknownPkgRefKind, fmt.Errorf(
		"could not determine package reference kind from repository URL %v", repoURL)
}

func identityFromV1RepoURL(repoURL string) string {
	// TODO(chuck): IMPLEMENT ME!
	return ""
}

func newPinStateFromV1PinState(ps V1PinState) PinState {
	// TODO(chuck): IMPLEMENT ME!
	return nil
}
