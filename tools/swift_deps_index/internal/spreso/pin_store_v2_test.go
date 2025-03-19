package spreso_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spreso"
	"github.com/stretchr/testify/assert"
)

func TestV2PinKindPkgRefKind(t *testing.T) {
	actual := spreso.UnknownV2PinKind.PkgRefKind()
	assert.Equal(t, spreso.UnknownPkgRefKind, actual)

	actual = spreso.LocalSourceControlV2PinKind.PkgRefKind()
	assert.Equal(t, spreso.LocalSourceControlPkgRefKind, actual)

	actual = spreso.RemoteSourceControlV2PinKind.PkgRefKind()
	assert.Equal(t, spreso.RemoteSourceControlPkgRefKind, actual)

	actual = spreso.RegistryV2PinKind.PkgRefKind()
	assert.Equal(t, spreso.RegistryPkgRefKind, actual)
}

func TestNewPinFromV2Pin(t *testing.T) {
	v2p := &spreso.V2Pin{
		Identity: "swift-argument-parser",
		Kind:     spreso.RemoteSourceControlV2PinKind,
		Location: "https://github.com/apple/swift-argument-parser",
		State: &spreso.V2PinState{
			Revision: "fddd1c00396eed152c45a46bea9f47b98e59301d",
			Version:  "1.2.0",
		},
	}
	actual, err := spreso.NewPinFromV2Pin(v2p)
	assert.NoError(t, err)
	expected := &spreso.Pin{
		PkgRef: &spreso.PackageReference{
			Identity: "swift-argument-parser",
			Kind:     spreso.RemoteSourceControlPkgRefKind,
			Location: "https://github.com/apple/swift-argument-parser",
		},
		State: &spreso.VersionPinState{
			Revision: "fddd1c00396eed152c45a46bea9f47b98e59301d",
			Version:  "1.2.0",
		},
	}
	assert.Equal(t, expected, actual)
}

func TestNewPinsFromV2PinStore(t *testing.T) {
	ps := &spreso.V2PinStore{
		Version: 2,
		Pins: []*spreso.V2Pin{
			{
				Identity: "swift-argument-parser",
				Kind:     spreso.RemoteSourceControlV2PinKind,
				Location: "https://github.com/apple/swift-argument-parser",
				State: &spreso.V2PinState{
					Revision: "fddd1c00396eed152c45a46bea9f47b98e59301d",
					Version:  "1.2.0",
				},
			},
		},
	}
	pins, err := spreso.NewPinsFromV2PinStore(ps)
	assert.NoError(t, err)
	assert.Len(t, pins, 1)
	assert.Equal(t, "swift-argument-parser", pins[0].PkgRef.Identity)
}
