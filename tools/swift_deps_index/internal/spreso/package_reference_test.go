package spreso_test

import (
	"encoding/json"
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spreso"
	"github.com/stretchr/testify/assert"
)

func strToPkgRefKind(val string) (spreso.PkgRefKind, error) {
	kind := spreso.UnknownPkgRefKind
	jsonVal, err := json.Marshal(val)
	if err != nil {
		return kind, err
	}
	if err := kind.UnmarshalJSON(jsonVal); err != nil {
		return kind, err
	}
	return kind, nil
}

func TestPkgRefKindUnmarshalJSON(t *testing.T) {
	tests := []struct {
		val  string
		wval spreso.PkgRefKind
	}{
		{val: "root", wval: spreso.RootPkgRefKind},
		{val: "fileSystem", wval: spreso.FileSystemPkgRefKind},
		{val: "localSourceControl", wval: spreso.LocalSourceControlPkgRefKind},
		{val: "remoteSourceControl", wval: spreso.RemoteSourceControlPkgRefKind},
		{val: "registry", wval: spreso.RegistryPkgRefKind},
	}
	for _, tc := range tests {
		actual, err := strToPkgRefKind(tc.val)
		assert.NoError(t, err)
		assert.Equal(t, tc.wval, actual)
	}
}
