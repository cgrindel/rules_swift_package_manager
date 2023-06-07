package swift_test

import (
	"fmt"
	"path/filepath"
	"testing"

	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/spreso"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestRepoRuleFromBazelRepo(t *testing.T) {
	repoDir := "/path/to/repo"
	pkgDir := "/path/to/repo"
	diBasename := "swift_deps_index.json"

	// TODO(chuck): Add test with patch

	t.Run("with pin (source control dep)", func(t *testing.T) {
		repoName := "swiftpkg_swift_argument_parser"
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
			Name: repoName,
			Pin:  p,
		}
		actual, err := swift.RepoRuleFromBazelRepo(br, diBasename, pkgDir, repoDir, nil)
		assert.NoError(t, err)

		expected := rule.NewRule(swift.SwiftPkgRuleKind, repoName)
		expected.SetAttr("commit", revision)
		expected.SetAttr("remote", remote)
		expected.SetAttr("dependencies_index", fmt.Sprintf("@//:%s", diBasename))
		expected.AddComment("# version: 1.2.3")
		assert.Equal(t, expected, actual)
	})
	t.Run("without pin (local Swift package)", func(t *testing.T) {
		repoDir := "/path/to/repo"
		pkgDir := "/path/to/repo"
		relLocalPkgDir := "third_party/cool_local_package"
		localPkgDir := filepath.Join(pkgDir, relLocalPkgDir)
		repoName := "swiftpkg_cool_local_package"

		br := &swift.BazelRepo{
			Name: repoName,
			PkgInfo: &swiftpkg.PackageInfo{
				Name: "cool-local-package",
				Path: localPkgDir,
			},
		}
		actual, err := swift.RepoRuleFromBazelRepo(br, diBasename, pkgDir, repoDir, nil)
		assert.NoError(t, err)

		expected := rule.NewRule(swift.LocalSwiftPkgRuleKind, repoName)
		expected.SetAttr("path", relLocalPkgDir)
		expected.SetAttr("dependencies_index", fmt.Sprintf("@//:%s", diBasename))
		assert.Equal(t, expected, actual)
	})
	t.Run("without pin (local Swift package with relative path)", func(t *testing.T) {
		repoDir := "/path/to/repo"
		pkgDir := "/path/to/repo/third_party"
		relLocalPkgDir := "../cool_local_package"
		localPkgDir := filepath.Clean(filepath.Join(pkgDir, relLocalPkgDir))
		repoName := "swiftpkg_cool_local_package"

		br := &swift.BazelRepo{
			Name: repoName,
			PkgInfo: &swiftpkg.PackageInfo{
				Name: "cool-local-package",
				Path: localPkgDir,
			},
		}
		actual, err := swift.RepoRuleFromBazelRepo(br, diBasename, pkgDir, repoDir, nil)
		assert.NoError(t, err)

		expected := rule.NewRule(swift.LocalSwiftPkgRuleKind, repoName)
		expected.SetAttr("path", "cool_local_package")
		expected.SetAttr("dependencies_index", fmt.Sprintf("@//:%s", diBasename))
		assert.Equal(t, expected, actual)
	})
}
