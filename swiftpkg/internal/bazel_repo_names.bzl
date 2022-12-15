"""Module for creating Bazel repository names."""

# The logic in from_url must stay in-sync with the RepoNameFromURL logic in
# gazelle/internal/swift/repo_name.go.
def _from_url(url):
    """Generates a repository name from a URL.

    Args:
        url: A URL as a `string`.

    Returns:
        A `string` value suitable for use as a Bazel label repository name.
    """
    if url.startswith("https://"):
        host_and_path = url.removeprefix("https://")
    elif url.startswith("http://"):
        host_and_path = url.removeprefix("http://")
    else:
        fail("Only https:// and http:// URLs are supported. url:", url)
    host_and_path = host_and_path.removesuffix(".git")
    host_sep_idx = host_and_path.find("/")
    if host_sep_idx < 0:
        fail("Invalid URL: host separator was not found. url:", url)
    elif host_sep_idx == 0:
        fail("Invalid URL: host not specified. url:", url)
    path = host_and_path[host_sep_idx + 1:]
    return _normalize(path.replace("/", "_").replace("-", "_"))

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
    from_url = _from_url,
    normalize = _normalize,
)
