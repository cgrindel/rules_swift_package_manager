package swift_test

import (
	"path/filepath"
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spreso"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestNewPackageFromBazelRepo(t *testing.T) {
	repoRoot := "/path/to/package"
	pkgDir := "/path/to/package"
	diBasename := "swift_deps_index.json"

	t.Run("with pin (source control dep)", func(t *testing.T) {
		repoName := "swiftpkg_swift_argument_parser"
		identity := "swift-argument-parser"
		remote := "https://github.com/apple/swift-argument-parser"
		version := "1.2.3"
		revision := "12345"
		p := &spreso.Pin{
			PkgRef: &spreso.PackageReference{
				Kind:     spreso.RemoteSourceControlPkgRefKind,
				Location: remote,
			},
			State: &spreso.VersionPinState{
				Version:  version,
				Revision: revision,
			},
		}
		br := &swift.BazelRepo{
			Name:     repoName,
			Identity: identity,
			Pin:      p,
		}
		actual, err := swift.NewPackageFromBazelRepo(br, diBasename, pkgDir, repoRoot, nil)
		assert.NoError(t, err)
		expected := &swift.Package{
			Name:     repoName,
			Identity: identity,
			Remote: &swift.RemotePackage{
				Commit:  revision,
				Remote:  remote,
				Version: version,
			},
		}
		assert.Equal(t, expected, actual)
	})
	t.Run("with pin (source control dep) and patch", func(t *testing.T) {
		repoName := "swiftpkg_swift_argument_parser"
		identity := "swift-argument-parser"
		remote := "https://github.com/apple/swift-argument-parser"
		version := "1.2.3"
		revision := "12345"
		p := &spreso.Pin{
			PkgRef: &spreso.PackageReference{
				Kind:     spreso.RemoteSourceControlPkgRefKind,
				Location: remote,
			},
			State: &spreso.VersionPinState{
				Version:  version,
				Revision: revision,
			},
		}
		br := &swift.BazelRepo{
			Name:     repoName,
			Identity: identity,
			Pin:      p,
		}
		patch := &swift.Patch{
			Args:  []string{"-p1"},
			Files: []string{"@@//third-party/foo:0001-fix.patch"},
		}
		actual, err := swift.NewPackageFromBazelRepo(br, diBasename, pkgDir, repoRoot, patch)
		assert.NoError(t, err)
		expected := &swift.Package{
			Name:     repoName,
			Identity: identity,
			Remote: &swift.RemotePackage{
				Commit:  revision,
				Remote:  remote,
				Version: version,
				Patch:   patch,
			},
		}
		assert.Equal(t, expected, actual)
	})
	t.Run("without pin (local Swift package)", func(t *testing.T) {
		pkgDir := "/path/to/package"
		relLocalPkgDir := "third_party/cool_local_package"
		localPkgDir := filepath.Join(pkgDir, relLocalPkgDir)
		repoName := "swiftpkg_cool_local_package"
		identity := "cool-local-package"

		br := &swift.BazelRepo{
			Name:     repoName,
			Identity: identity,
			PkgInfo: &swiftpkg.PackageInfo{
				Name: "cool-local-package",
				Path: localPkgDir,
			},
		}
		actual, err := swift.NewPackageFromBazelRepo(br, diBasename, pkgDir, repoRoot, nil)
		assert.NoError(t, err)
		expected := &swift.Package{
			Name:     repoName,
			Identity: identity,
			Local: &swift.LocalPackage{
				Path: relLocalPkgDir,
			},
		}
		assert.Equal(t, expected, actual)
	})
}
