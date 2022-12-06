"""Module for creating Bazel repository names."""

# The logic in from_url should stay in-sync with the RepoNameFromURL logic in
# gazelle/internal/swift/repo_name.go.
def _from_url(url):
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
    return path.replace("/", "_").replace("-", "_")

bazel_repo_names = struct(
    from_url = _from_url,
)
