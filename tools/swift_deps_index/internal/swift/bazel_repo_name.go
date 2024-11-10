package swift

import (
	"strings"
)

// The logic in RepoNameFromIdentity must stay in-sync with bazel_repo_names.from_identity in
// swiftpkg/internal/bazel_repo_names.bzl.

func normalizeStrForRepoName(v string) string {
	return strings.ReplaceAll(v, "-", "_")
}

// RepoNameFromIdentity returns a Bazel repository name from a Swift package identity/name.  The
// value produced by this function will not have the `@` character appended. This is handled by
// label.Label.
func RepoNameFromIdentity(id string) string {
	return "swiftpkg_" + normalizeStrForRepoName(id)
}
