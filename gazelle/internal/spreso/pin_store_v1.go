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

func NewPinsFromV1PinStore(ps V1PinStore) ([]*Pin, error) {
	pins := make([]*Pin, len(ps.Object.Pins))
	for idx, psp := range ps.Object.Pins {
		pin, err := newPinFromV1PinStore(psp)
		if err != nil {
			return nil, err
		}
		pins[idx] = pin
	}
	return pins, nil
}

func newPinFromV1PinStore(psp V1Pin) (*Pin, error) {
	kind, err := pkgRefKindFromV1RepoURL(psp.RepositoryURL)
	if err != nil {
		return nil, err
	}
	return &Pin{
		PkgRef: &PackageReference{
			Identity: identityFromV1RepoURL(psp.RepositoryURL),
			Kind: kind,
			Location: psp.RepositoryURL,
			Name:     psp.Package,
		},
		State: newPinStateFromV1PinState(psp.State),
	}, nil
}

func pkgRefKindFromV1RepoURL(repoURL string) (PkgRefKind, error) {
	// TODO(chuck): IMPLEMENT ME!
	return UnknownPkgRefKind, nil
}

func identityFromV1RepoURL(repoURL string) string {
	// TODO(chuck): IMPLEMENT ME!
	return ""
}

func newPinStateFromV1PinState(ps V1PinState) PinState {
	// TODO(chuck): IMPLEMENT ME!
	return nil
}
