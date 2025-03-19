package swift_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestBzlmodStanzas(t *testing.T) {
	awesomeRepoId := "awesome-repo"
	awesomePkg := &swift.Package{
		Name:     swift.RepoNameFromIdentity(awesomeRepoId),
		Identity: awesomeRepoId,
		Remote: &swift.RemotePackage{
			Commit: "12345",
			Remote: "https://github.com/example/awesome-repo",
		},
	}
	anotherRepoID := "another-repo"
	anotherPkg := &swift.Package{
		Name:     swift.RepoNameFromIdentity(anotherRepoID),
		Identity: anotherRepoID,
		Local: &swift.LocalPackage{
			Path: "path/to/another",
		},
	}

	di := swift.NewDependencyIndex()
	di.AddPackage(awesomePkg, anotherPkg)
	di.AddDirectDependency(awesomeRepoId, anotherRepoID)

	actual, err := swift.BzlmodStanzas(di, "path/to/root", "path/to/root/swift_deps_index.json")
	assert.NoError(t, err)
	expected := `swift_deps = use_extension(
    "@rules_swift_package_manager//:extensions.bzl",
    "swift_deps",
)
swift_deps.from_file(
    deps_index = "//:swift_deps_index.json",
)
use_repo(
    swift_deps,
    "swiftpkg_another_repo",
    "swiftpkg_awesome_repo",
)
`
	assert.Equal(t, expected, actual)
}

func TestBzlmodStanzasWithCustomDepsIndex(t *testing.T) {
	awesomeRepoId := "awesome-repo"
	awesomePkg := &swift.Package{
		Name:     swift.RepoNameFromIdentity(awesomeRepoId),
		Identity: awesomeRepoId,
		Remote: &swift.RemotePackage{
			Commit: "12345",
			Remote: "https://github.com/example/awesome-repo",
		},
	}
	anotherRepoID := "another-repo"
	anotherPkg := &swift.Package{
		Name:     swift.RepoNameFromIdentity(anotherRepoID),
		Identity: anotherRepoID,
		Local: &swift.LocalPackage{
			Path: "path/to/another",
		},
	}

	di := swift.NewDependencyIndex()
	di.AddPackage(awesomePkg, anotherPkg)
	di.AddDirectDependency(awesomeRepoId, anotherRepoID)

	actual, err := swift.BzlmodStanzas(di, "path/to/root", "path/to/root/swift/deps_index.json")
	assert.NoError(t, err)
	expected := `swift_deps = use_extension(
    "@rules_swift_package_manager//:extensions.bzl",
    "swift_deps",
)
swift_deps.from_file(
    deps_index = "//swift:deps_index.json",
)
use_repo(
    swift_deps,
    "swiftpkg_another_repo",
    "swiftpkg_awesome_repo",
)
`
	assert.Equal(t, expected, actual)
}
