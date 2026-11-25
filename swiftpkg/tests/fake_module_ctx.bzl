"""A fake `module_ctx` over an in-memory file tree, for extension tests.

Labels in the main repository map to paths under `WORKSPACE` (for example,
`@@//swift/macos:Package.resolved` is `/ws/swift/macos/Package.resolved`).
Paths are plain `string` values.

A fake `path` cannot support `str()`, so code under test that needs a path as
a `string` takes it as an argument instead. `staleness_collect` returns a
drop-in for `staleness.collect` that reads the same files.
"""

load("//swiftpkg/internal:staleness.bzl", "staleness_testing")

WORKSPACE = "/ws"

def _key(path_or_label):
    if type(path_or_label) == "Label":
        root = WORKSPACE
        if path_or_label.repo_name:
            root = "/external/" + path_or_label.repo_name
        if path_or_label.package:
            return "{}/{}/{}".format(root, path_or_label.package, path_or_label.name)
        return "{}/{}".format(root, path_or_label.name)
    if type(path_or_label) == "struct":
        return path_or_label.key
    return path_or_label

def _normalize(path):
    parts = []
    for part in path.split("/"):
        if part == "" or part == ".":
            continue
        if part == "..":
            if parts:
                parts.pop()
            continue
        parts.append(part)
    return "/" + "/".join(parts)

def _dirname(path):
    return path.rpartition("/")[0] or "/"

def _exists(files, key):
    if key in files:
        return True
    prefix = key + "/"
    for f in files:
        if f.startswith(prefix):
            return True
    return False

def _readdir(files, key):
    prefix = key + "/"
    names = {}
    for f in files:
        if f.startswith(prefix):
            names[f[len(prefix):].split("/")[0]] = None
    return sorted(names)

def _new(files = {}, modules = [], metadata = None):
    """Creates a fake `module_ctx`.

    Args:
        files: A `dict` of absolute path to file contents.
        modules: The value of `module_ctx.modules`.
        metadata: Optional. A `dict` that receives the kwargs passed to
            `extension_metadata`.

    Returns:
        A `struct` that mimics a `module_ctx`. It also has `watched`, the
        list of paths passed to `watch`. `is_dev_dependency` reads the fake
        tag's `is_dev` field. `execute` always fails, so `test -d` and
        `test -e` report that nothing exists.
    """
    watched = []

    def _path(path_or_label):
        key = _key(path_or_label)
        return struct(key = key, exists = _exists(files, key))

    def _read(path):
        return files[_key(path)]

    def _watch(path):
        watched.append(_key(path))

    def _execute(*_args, **_kwargs):
        return struct(return_code = 1, stdout = "", stderr = "")

    def _extension_metadata(**kwargs):
        if metadata != None:
            metadata.update(kwargs)
        return struct(extension_metadata = kwargs)

    return struct(
        path = _path,
        read = _read,
        watch = _watch,
        watched = watched,
        execute = _execute,
        modules = modules,
        is_dev_dependency = lambda tag: tag.is_dev,
        extension_metadata = _extension_metadata,
    )

def _new_reader(files):
    return struct(
        exists = lambda p: _exists(files, _key(p)),
        read = lambda p: files.get(_key(p)),
        readdir = lambda p: _readdir(files, _key(p)),
        watch = lambda _p: None,
        dirname = lambda p: _dirname(_key(p)),
        join = lambda dir, rel: _normalize(rel if rel.startswith("/") else dir + "/" + rel),
    )

def _staleness_collect(files):
    """Returns a stand-in for `staleness.collect` that reads `files`.

    Args:
        files: A `dict` of absolute path to file contents.

    Returns:
        A function with the signature of `staleness.collect`.
    """
    reader = _new_reader(files)

    def _collect(_module_ctx, slice, config_swift_package, patch_files_by_identity):
        return staleness_testing.collect_with_reader(
            reader,
            slice,
            config_swift_package,
            patch_files_by_identity,
        )

    return _collect

fake_module_ctx = struct(
    key = _key,
    new = _new,
    staleness_collect = _staleness_collect,
)
