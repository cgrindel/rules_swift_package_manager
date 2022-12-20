"""Module for creating Bazel repository names."""

# The logic in from_identity must stay in-sync with the RepoNameFromIdentity
# logic in gazelle/internal/swift/bazel_repo_name.go.

def _from_identity(identity):
    """Create a Bazel repository name from a Swift package identity (e.g. \
    package name in the manifest)

    The value produced by this function will not have the `@` character
    appended. Code that needs to use it as a label repository name should pass
    it to bazel_repo_names.normalize().

    Args:
        identity: A Swift package name/identity as a `string`.

    Returns:
        A Bazel repository name as a `string`.
    """
    return "swiftpkg_" + identity.replace("-", "_")

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
