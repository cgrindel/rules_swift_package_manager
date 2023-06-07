"""Module for retrieving and categorizing clang files."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:sets.bzl", "sets")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")
load("//swiftpkg/internal/modulemap_parser:declarations.bzl", dts = "declaration_types")
load("//swiftpkg/internal/modulemap_parser:parser.bzl", modulemap_parser = "parser")

# Directory names that may include public header files.
_PUBLIC_HDR_DIRNAMES = ["include", "public"]

# Supported header extensions
# https://bazel.build/reference/be/c-cpp#cc_library.srcs
_HEADER_EXTS = [".h", ".hh", ".hpp", ".hxx", ".inl", ".H"]

# Acceptable sources clang and objc:
# https://bazel.build/reference/be/c-cpp#cc_library.srcs
# https://bazel.build/reference/be/objective-c#objc_library.srcs
# NOTE: From examples found so far, .inc files tend to include source, not
# header declarations.
_SRC_EXTS = [".c", ".cc", ".S", ".so", ".o", ".m", ".inc"]

def _is_hdr(path):
    _root, ext = paths.split_extension(path)
    return lists.contains(_HEADER_EXTS, ext)

def _is_include_hdr(path, public_includes = None):
    """Determines whether the path is a public header.

    Args:
        path: A path `string` value.
        public_includes: Optional. A `sequence` of path `string` values that
                         are used to identify public header files.

    Returns:
        A `bool` indicating whether the path is a public header.
    """
    if not _is_hdr(path):
        return False

    public_includes = [] if public_includes == None else public_includes
    if len(public_includes) > 0:
        for include_path in public_includes:
            if include_path[-1] != "/":
                include_path += "/"
            if path.startswith(include_path):
                return True
    else:
        for dirname in _PUBLIC_HDR_DIRNAMES:
            if (path.find("/%s/" % dirname) > -1) or path.startswith("%s/" % dirname):
                return True
    return False

def _is_public_modulemap(path):
    """Determines whether the specified path is to a public `module.modulemap` file.

    Args:
        path: A path `string`.

    Returns:
        A `bool` indicating whether the path is a public `module.modulemap`
        file.
    """
    basename = paths.basename(path)
    return basename == "module.modulemap"

def _get_hdr_paths_from_modulemap(repository_ctx, modulemap_path, module_name):
    """Retrieves the list of headers declared in the specified modulemap file \
    for the specified module.

    If the specified module is not found, all of the headers from the top-level
    modules are returned.

    Args:
        repository_ctx: A `repository_ctx` instance.
        modulemap_path: A path `string` to the `module.modulemap` file.
        module_name: The name of the module.

    Returns:
        A `list` of path `string` values.
    """
    modulemap_str = repository_ctx.read(modulemap_path)
    decls, err = modulemap_parser.parse(modulemap_str)
    if err != None:
        fail("Errors parsing the %s. %s" % (modulemap_path, err))

    module_decls = [d for d in decls if d.decl_type == dts.module]
    if len(module_decls) == 0:
        fail("No module declarations were found in %s." % (modulemap_path))

    # Look for a module declaration that matches the module name. Only select
    # headers from that module if it is found. Otherwise, we collect all of the
    # headers in all of the module declarations at the top-level.
    module_decl = lists.find(module_decls, lambda m: m.module_id == module_name)
    if module_decl != None:
        module_decls = [module_decl]

    modulemap_dirname = paths.dirname(modulemap_path)
    hdrs = []
    for module_decl in module_decls:
        for cdecl in module_decl.members:
            if cdecl.decl_type == dts.single_header and not cdecl.private and not cdecl.textual:
                # Resolve the path relative to the modulemap
                hdr_path = paths.join(modulemap_dirname, cdecl.path)
                normalized_hdr_path = paths.normalize(hdr_path)
                hdrs.append(normalized_hdr_path)

    return hdrs

def _is_under_path(path, parent):
    """Determines whether a path is under a another path.

    Args:
        path: The path to be evaluated as a `string`.
        parent: The parent path as a `string`.

    Returns:
        A `bool` representing whether the path is under the parent path.
    """
    path = path.removesuffix("/")
    parent = parent.removesuffix("/")
    if path == parent:
        return True
    parent_prefix = parent if parent.endswith("/") else parent + "/"
    if path.startswith(parent_prefix):
        return True
    return False

def _relativize(path, relative_to):
    """Returns a path relative to another path.

    If `relative_to` is `None`, the `path` is returned.
    If `path` equals `relative_to`, dot is returned.
    If `path` starts with `relative_to`, the relative path is returned.
    Otherwise, the `path` is not under `relative_to`. The `path` is returned.

    This differs from `paths.relativize` in that this will not fail if the path
    is not under `relative_to`.

    Args:
        path: The path to be relativized as a `string`.
        relative_to: The parent path as a `string`.

    Returns:
        The relative path as a `string`.
    """
    if relative_to == None:
        return path
    if path == relative_to:
        return "."
    if path.startswith(relative_to):
        return paths.relativize(path, relative_to)
    return path

def _relativize_paths(paths_list, relative_to):
    return [
        _relativize(path, relative_to)
        for path in paths_list
    ]

def _collect_files(
        repository_ctx,
        all_srcs,
        module_name,
        public_includes = [],
        relative_to = None,
        is_library = True):
    # hdrs: Public headers
    # srcs: Private headers and source files.
    # others: Uncategorized
    # modulemap: Public modulemap
    hdrs_set = sets.make()
    srcs_set = sets.make()
    others_set = sets.make()

    modulemap = None
    modulemap_orig_path = None
    for orig_path in all_srcs:
        path = _relativize(orig_path, relative_to)
        _root, ext = paths.split_extension(path)
        if lists.contains(_HEADER_EXTS, ext):
            if _is_include_hdr(orig_path, public_includes = public_includes):
                sets.insert(hdrs_set, path)
            else:
                sets.insert(srcs_set, path)
        elif lists.contains(_SRC_EXTS, ext):
            sets.insert(srcs_set, path)
        elif ext == ".modulemap" and _is_public_modulemap(path):
            if modulemap != None:
                fail("Found multiple modulemap files. {first} {second}".format(
                    first = modulemap,
                    second = path,
                ))
            modulemap_orig_path = orig_path
            modulemap = path
        else:
            sets.insert(others_set, path)

    # The apple/swift-crypto package has a CCryptoBoringSSL target that has a
    # modulemap in their include directory, but it only lists the top-level
    # header. The modulemap spec suggests that the header is parsed and all of
    # the referenced headers are included. For now, we will just add the
    # modulemap hdrs to the ones that we have already found.
    if modulemap_orig_path != None:
        mm_hdrs = _get_hdr_paths_from_modulemap(
            repository_ctx,
            modulemap_orig_path,
            module_name,
        )
        mm_hdrs = _relativize_paths(mm_hdrs, relative_to)

        # There are modulemaps in the wild (e.g.,
        # https://github.com/1024jp/GzipSwift) that list system headers (i.e.,
        # absolute path to a system header). Filter them out AFTER we remove the
        # prefixes.
        mm_hdrs = lists.compact([
            hdr if not paths.is_absolute(hdr) else None
            for hdr in mm_hdrs
        ])

        mm_hdrs_set = sets.make(mm_hdrs)
        hdrs_set = sets.union(hdrs_set, mm_hdrs_set)

    # If we have not found any public header files for a library module, then
    # promote any headers that are listed in the srcs.
    # Example: CVaporBcrypt in https://github.com/vapor/vapor.git
    if is_library and sets.length(hdrs_set) == 0 and len(public_includes) == 0:
        for src in sets.to_list(srcs_set):
            if _is_hdr(src):
                sets.insert(hdrs_set, src)
        srcs_set = sets.difference(srcs_set, hdrs_set)

    # If public includes were specified, then use them. Otherwise, add every
    # directory that holds a public header file
    if len(public_includes) == 0:
        public_includes = [paths.dirname(hdr) for hdr in sets.to_list(hdrs_set)]

    public_includes = _relativize_paths(public_includes, relative_to)
    public_includes_set = sets.make(public_includes)

    # Add each directory that contains a private header to the includes
    private_includes_set = sets.make([
        paths.dirname(src)
        for src in sets.to_list(srcs_set)
        if _is_hdr(src)
    ])

    hdrs = sets.to_list(hdrs_set)
    srcs = sets.to_list(srcs_set)
    others = sets.to_list(others_set)
    public_includes = sets.to_list(public_includes_set)
    private_includes = sets.to_list(private_includes_set)

    # Textual headers
    textual_hdrs = []
    for src in srcs:
        if not _is_hdr(src):
            textual_hdrs.append(src)

    # Remove the prefixes before returning the results
    return struct(
        hdrs = sorted(hdrs),
        srcs = sorted(srcs),
        public_includes = sorted(public_includes),
        private_includes = sorted(private_includes),
        modulemap = modulemap,
        others = sorted(others),
        textual_hdrs = sorted(textual_hdrs),
    )

clang_files = struct(
    collect_files = _collect_files,
    get_hdr_paths_from_modulemap = _get_hdr_paths_from_modulemap,
    is_hdr = _is_hdr,
    is_include_hdr = _is_include_hdr,
    is_public_modulemap = _is_public_modulemap,
    is_under_path = _is_under_path,
    relativize = _relativize,
)
