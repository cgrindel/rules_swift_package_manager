package swift_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestPackageIndex(t *testing.T) {
	fooRepoID := "foo"
	fooPkg := &swift.Package{
		Name:     swift.RepoNameFromIdentity(fooRepoID),
		Identity: fooRepoID,
		Remote: &swift.RemotePackage{
			Commit: "12345",
			Remote: "https://github.com/example/foo",
		},
	}
	barRepoID := "bar"
	barPkg := &swift.Package{
		Name:     swift.RepoNameFromIdentity(barRepoID),
		Identity: barRepoID,
		Local: &swift.LocalPackage{
			Path: "path/to/bar",
		},
	}
	pi := swift.NewPackageIndex(fooPkg, barPkg)

	t.Run("packages", func(t *testing.T) {
		expected := []*swift.Package{barPkg, fooPkg}
		actual := pi.Packages()
		assert.Equal(t, expected, actual)
	})
}
