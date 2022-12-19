package swift

import (
	"fmt"
	"strings"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

// TODO(chuck): Update bazel_repo_names.bzl with new logic.

// TODO(chuck): Rename this to bazel_repo_name.go.

// The logic in RepoNameFromURL must stay in-sync with bazel_repo_names.from_url in
// swiftpkg/internal/bazel_repo_names.bzl.

func normalizeStrForRepoName(v string) string {
	return strings.ReplaceAll(v, "-", "_")
}

func RepoNameFromIdentity(id string) string {
	return "swiftpkg_" + normalizeStrForRepoName(id)
}

func RepoNameFromDep(dep *swiftpkg.Dependency) (string, error) {
	if id := dep.Identity(); id != "" {
		return RepoNameFromIdentity(id), nil

	}
	return "", fmt.Errorf("unable to determine repo name from dependency %v", dep.Identity())
}
