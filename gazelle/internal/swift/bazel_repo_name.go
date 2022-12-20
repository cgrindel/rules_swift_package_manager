package swift

import (
	"fmt"
	"strings"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

// The logic in RepoNameFromIdentity must stay in-sync with bazel_repo_names.from_identity in
// swiftpkg/internal/bazel_repo_names.bzl.

func normalizeStrForRepoName(v string) string {
	return strings.ReplaceAll(v, "-", "_")
}

// Returns a Bazel repository name from a Swift package identity/name.  The value produced by this
// function will not have the `@` character appended. This is handled by label.Label.
func RepoNameFromIdentity(id string) string {
	return "swiftpkg_" + normalizeStrForRepoName(id)
}

func RepoNameFromDep(dep *swiftpkg.Dependency) (string, error) {
	if id := dep.Identity(); id != "" {
		return RepoNameFromIdentity(id), nil

	}
	return "", fmt.Errorf("unable to determine repo name from dependency %v", dep.Identity())
}
