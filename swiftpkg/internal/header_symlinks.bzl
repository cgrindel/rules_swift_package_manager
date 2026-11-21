"""Module for finding header symlinks inside a Swift package and recreating them."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(":clang_files.bzl", "clang_files")
load(":repository_files.bzl", "repository_files")

# Symlinks inside these directories are part of a binary artifact's layout.
_BUNDLE_DIR_EXTS = [".framework", ".xcframework"]

_MODES = struct(
    ignore = "ignore",
    replace = "replace",
    warn = "warn",
)

_MODE_VALUES = [_MODES.warn, _MODES.ignore, _MODES.replace]

# Lists the header symlinks found, one `<path> -> <target>` per line, at the
# root of the generated repository.
_LIST_FILE = "rspm_header_symlinks.txt"

_ATTRS = {
    "header_symlinks": attr.string(
        default = _MODES.warn,
        values = _MODE_VALUES,
        doc = """\
How to handle header symlinks inside the package: `"warn"`, `"ignore"` or \
`"replace"`.

Bazel sends a source file that is a symlink to a remote executor as a regular \
file. Executors that write each input as its own copy (e.g. BuildBuddy's macOS \
executor) then give clang two different files with the same contents, so a \
header without include guards can be included twice.

Only header symlinks that resolve to a file inside the package count. \
Symlinks inside `.framework` and `.xcframework` directories, directory \
symlinks, and symlinks that point outside the package are never changed.

- `"warn"` (default): change nothing and print a one-line warning with the \
  number of header symlinks. The full list is written to \
  `rspm_header_symlinks.txt` at the root of the generated repository.
- `"ignore"`: change nothing and print nothing. Use this for a package whose \
  header symlinks build correctly.
- `"replace"`: remove each header symlink from the repository and recreate it \
  at the same package-relative path in the output tree with \
  `ctx.actions.declare_symlink`, which Bazel sends to remote executors as a \
  symlink. Its directory is added to the target's `includes`, so that quoted \
  includes from the header and of the header resolve for every compile, \
  including the explicit module precompile.

rules_swift_package_manager does not modify local packages or packages with a \
`build_file`, so `"replace"` behaves like `"warn"` for them.\
""",
    ),
}

# Suffix of the generated target that recreates a header symlink.
_LABEL_NAME_SUFFIX = ".rspm_symlink"

def _new_link(path, target):
    """Create a header symlink.

    Args:
        path: The symlink's path relative to the package root as a `string`.
        target: The path of the file that the symlink finally resolves to,
            relative to the package root, as a `string`.

    Returns:
        A `struct` representing the symlink.
    """
    return struct(path = path, target = target)

def _new_entry(path, realpath = None, is_dir = False):
    """Create a symlink found on disk, before it is filtered.

    Args:
        path: The symlink's path relative to the package root as a `string`.
        realpath: The absolute path that the symlink resolves to as a
            `string`, or `None` if it does not resolve.
        is_dir: A `bool` indicating whether the symlink resolves to a
            directory.

    Returns:
        A `struct` representing the symlink.
    """
    return struct(path = path, realpath = realpath, is_dir = is_dir)

def _is_in_bundle_dir(path):
    for part in path.split("/")[:-1]:
        for ext in _BUNDLE_DIR_EXTS:
            if part.endswith(ext):
                return True
    return False

def _select_links(root, entries):
    """Select the symlinks that should be replaced.

    Args:
        root: The absolute, resolved path of the package root as a `string`.
        entries: A `list` of `struct` values from `header_symlinks.new_entry`.

    Returns:
        A `list` of `struct` values from `header_symlinks.new_link`, sorted by
        path.
    """
    root_prefix = root.rstrip("/") + "/"
    links = []
    for entry in sorted(entries, key = lambda e: e.path):
        if not clang_files.is_hdr(entry.path) or _is_in_bundle_dir(entry.path):
            continue
        if entry.realpath == None or entry.is_dir:
            continue
        if not entry.realpath.startswith(root_prefix):
            continue
        target = entry.realpath.removeprefix(root_prefix)
        if _is_in_bundle_dir(target):
            continue
        links.append(_new_link(entry.path, target))
    return links

def _effective_mode(mode, local = False, has_build_file = False):
    """Return how to handle a package's header symlinks.

    Args:
        mode: The requested mode: `"warn"`, `"ignore"` or `"replace"`.
        local: A `bool` indicating whether the package is a local package.
        has_build_file: A `bool` indicating whether a `build_file` replaces the
            generated `BUILD.bazel` file.

    Returns:
        The mode as a `string`.
    """
    if mode == _MODES.ignore:
        return _MODES.ignore
    if mode == _MODES.replace and not local and not has_build_file:
        return _MODES.replace
    return _MODES.warn

def _warning(name, count, local = False, has_build_file = False):
    """Return the one-line warning for a package's header symlinks.

    Args:
        name: The package's repository name as a `string`.
        count: The number of header symlinks as an `int`.
        local: A `bool` indicating whether the package is a local package.
        has_build_file: A `bool` indicating whether a `build_file` replaces the
            generated `BUILD.bazel` file.

    Returns:
        The warning as a `string` without line breaks.
    """
    if local:
        advice = "rules_swift_package_manager does not modify local packages, \
so replace them with forwarding headers in the source, or set \
header_symlinks = \"ignore\" with swift_deps.configure_package."
    elif has_build_file:
        advice = "header_symlinks = \"replace\" has no effect with build_file, \
so recreate them in that BUILD file, or set header_symlinks = \"ignore\" with \
swift_deps.configure_package."
    else:
        advice = "set header_symlinks = \"replace\" (or \"ignore\") with \
swift_deps.configure_package."
    return "WARNING: {name} has {count} header symlink{s} (listed in {file}) \
that remote execution duplicates; {advice}".format(
        name = name,
        count = count,
        s = "" if count == 1 else "s",
        file = _LIST_FILE,
        advice = advice,
    )

def _label_name(link):
    return link.path + _LABEL_NAME_SUFFIX

def _is_under(path, directory):
    return directory in ["", "."] or path.startswith(directory.rstrip("/") + "/")

def _links_for_target(links, target_path, public_includes = [], private_includes = []):
    """Select the header symlinks that belong to a clang target.

    A symlink belongs to the target when it lives under the target's path or
    under one of its include directories.

    Args:
        links: A `list` of `struct` values from `header_symlinks.new_link`.
        target_path: The target's path relative to the package root.
        public_includes: The target's public include directories relative to
            the package root.
        private_includes: The target's private include directories relative
            to the package root.

    Returns:
        A `struct` with `hdrs` (symlinks under a public include directory) and
        `srcs` (the others), each a `list` sorted by path.
    """
    hdrs = []
    srcs = []
    for link in sorted(links, key = lambda l: l.path):
        if [d for d in public_includes if _is_under(link.path, d)]:
            hdrs.append(link)
        elif _is_under(link.path, target_path) or \
             [d for d in private_includes if _is_under(link.path, d)]:
            srcs.append(link)
    return struct(hdrs = hdrs, srcs = srcs)

def _include_dirs(links):
    """Return the sorted, unique directories that contain the symlinks."""
    return sorted({paths.dirname(link.path): None for link in links}.keys())

def _find(repository_ctx, directory):
    """Find the header symlinks inside a package directory.

    Args:
        repository_ctx: A `repository_ctx` instance.
        directory: The package directory as a `string`.

    Returns:
        A `list` of `struct` values from `header_symlinks.new_link`.
    """
    entries = []
    for path in repository_files.list_symlinks_under(repository_ctx, directory):
        if not clang_files.is_hdr(path):
            continue
        abs_path = paths.join(directory, path)
        if not repository_ctx.path(abs_path).exists:
            entries.append(_new_entry(path))
            continue
        entries.append(_new_entry(
            path,
            realpath = str(repository_ctx.path(abs_path).realpath),
            is_dir = repository_files.is_directory(repository_ctx, abs_path),
        ))
    root = str(repository_ctx.path(directory).realpath)
    return _select_links(root, entries)

def _process(repository_ctx, directory, mode, local = False, has_build_file = False):
    """Find a package's header symlinks and handle them according to `mode`.

    Args:
        repository_ctx: A `repository_ctx` instance.
        directory: The package directory as a `string`.
        mode: The `header_symlinks` attribute value.
        local: A `bool` indicating whether the package is a local package,
            which is never modified.
        has_build_file: A `bool` indicating whether a `build_file` replaces the
            generated `BUILD.bazel` file, which cannot recreate the symlinks.

    Returns:
        A `struct` with `found` (the header symlinks found) and `removed` (the
        ones removed so that the generated `BUILD.bazel` file recreates them),
        each a `list` of `struct` values from `header_symlinks.new_link`.
    """
    mode = _effective_mode(mode, local = local, has_build_file = has_build_file)
    if mode == _MODES.ignore:
        return struct(found = [], removed = [])
    links = _find(repository_ctx, directory)
    if not links:
        return struct(found = [], removed = [])
    if mode == _MODES.warn:
        # buildifier: disable=print
        print(_warning(
            _package_name(repository_ctx),
            len(links),
            local = local,
            has_build_file = has_build_file,
        ))
        return struct(found = links, removed = [])
    for link in links:
        repository_ctx.delete(paths.join(directory, link.path))
    return struct(found = links, removed = links)

def _list_content(links):
    return "".join(["{} -> {}\n".format(link.path, link.target) for link in links])

def _write_list(repository_ctx, links):
    """Write the header symlinks to a file at the root of the repository.

    Call this after generating the `BUILD.bazel` file, so that the file is
    never collected as a package source.

    Args:
        repository_ctx: A `repository_ctx` instance.
        links: A `list` of `struct` values from `header_symlinks.new_link`.
    """
    if links:
        repository_ctx.file(_LIST_FILE, content = _list_content(links), executable = False)

def _package_name(repository_ctx):
    return getattr(repository_ctx.attr, "bazel_package_name", None) or \
           repository_ctx.name

header_symlinks = struct(
    attrs = _ATTRS,
    effective_mode = _effective_mode,
    find = _find,
    include_dirs = _include_dirs,
    label_name = _label_name,
    links_for_target = _links_for_target,
    list_content = _list_content,
    list_file = _LIST_FILE,
    mode_values = _MODE_VALUES,
    modes = _MODES,
    new_entry = _new_entry,
    new_link = _new_link,
    process = _process,
    select_links = _select_links,
    warning = _warning,
    write_list = _write_list,
)
