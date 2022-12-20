"""Module for creating Bazel repository names."""

# The logic in from_url must stay in-sync with the RepoNameFromIdentity logic in
# gazelle/internal/swift/bazel_repo_name.go.

def _from_identity(identity):
    return "@swiftpkg_" + identity.replace("-", "_")

def _normalize(repo_name):
    """Ensures that the repository name is formatted properly (e.g. has @ suffix).

    Args:
        repo_name: The repository name as a `string`.

    Returns:
        The properly formatted repository name as a `string`.
    """
    if not repo_name.startswith("@"):
        repo_name = "@{}".format(repo_name)
    return repo_name

bazel_repo_names = struct(
    from_identity = _from_identity,
    normalize = _normalize,
)
