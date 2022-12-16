package swift

import (
	"fmt"
	"path"
	"strings"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

// The logic in RepoNameFromURL must stay in-sync with bazel_repo_names.from_url in
// swiftpkg/internal/bazel_repo_names.bzl.

func RepoNameFromURL(url string) (string, error) {
	if url == "" {
		return "", fmt.Errorf("URL cannot be empty string")
	}
	parts := strings.Split(url, "/")
	if partsLen := len(parts); partsLen >= 2 {
		parts = parts[len(parts)-2:]
	}

	// Normalize parts
	for idx, p := range parts {
		parts[idx] = normalizeStrForRepoName(p)
	}

	// Remove the extension from the last part of the URL
	lastidx := len(parts) - 1
	lastPart := parts[lastidx]
	if ext := path.Ext(lastPart); ext != "" {
		parts[lastidx] = strings.TrimSuffix(lastPart, ext)
	}

	// Put parts back together
	return strings.Join(parts, "_"), nil
}

func normalizeStrForRepoName(v string) string {
	return strings.ReplaceAll(v, "-", "_")
}

func RepoNameFromStr(v string) string {
	return normalizeStrForRepoName(v)
}

func RepoNameFromPin(p *spreso.Pin) (string, error) {
	switch p.PkgRef.Kind {
	case spreso.RemoteSourceControlPkgRefKind:
		return RepoNameFromURL(p.PkgRef.Location)
	default:
		return RepoNameFromStr(p.PkgRef.Identity), nil
	}
}

func RepoNameFromDep(dep *swiftpkg.Dependency) (string, error) {
	if url := dep.URL(); url != "" {
		return RepoNameFromURL(url)
	}
	return "", fmt.Errorf("unable to determine repo name from dependency %v", dep.Identity())
}
