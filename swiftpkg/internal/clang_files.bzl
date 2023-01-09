"""Module for retrieving and categorizing clang files."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:sets.bzl", "sets")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")
load("//swiftpkg/internal/modulemap_parser:declarations.bzl", dts = "declaration_types")
load("//swiftpkg/internal/modulemap_parser:parser.bzl", modulemap_parser = "parser")
load(":repository_files.bzl", "repository_files")

# Directory names that may include public header files.
_PUBLIC_HDR_DIRNAMES = ["include", "public"]

def _is_hdr(path):
    _root, ext = paths.split_extension(path)
    return ext == ".h"

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

    if public_includes != None:
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

def _get_hdr_paths_from_modulemap(repository_ctx, modulemap_path):
    """Retrieves the list of headers declared in the specified modulemap file.

    Args:
        repository_ctx: A `repository_ctx` instance.
        modulemap_path: A path `string` to the `module.modulemap` file.

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

def _remove_prefix(path, prefix):
    return _remove_prefixes([path], prefix)[0]

def _remove_prefixes(paths_list, prefix):
    if prefix == None:
        return paths_list
    prefix_len = len(prefix)
    return [
        path[prefix_len:] if path.startswith(prefix) else path
        for path in paths_list
    ]

def _collect_files(
        repository_ctx,
        root_paths,
        public_includes = None,
        remove_prefix = None):
    paths_list = []
    for root_path in root_paths:
        paths_list.extend(
            repository_files.list_files_under(
                repository_ctx,
                root_path,
            ),
        )

    # hdrs: Public headers
    # srcs: Private headers and source files.
    # others: Uncategorized
    # modulemap: Public modulemap
    hdrs_set = sets.make()
    srcs_set = sets.make()
    others_set = sets.make()
    public_includes_set = sets.make()
    modulemap = None
    modulemap_orig_path = None
    for orig_path in paths_list:
        path = _remove_prefix(orig_path, remove_prefix)
        _root, ext = paths.split_extension(path)
        if ext == ".h":
            if _is_include_hdr(orig_path, public_includes = public_includes):
                sets.insert(hdrs_set, path)
                sets.insert(public_includes_set, paths.dirname(path))
            else:
                sets.insert(srcs_set, path)
        elif lists.contains([".c", ".cc", ".S", ".so", ".o", ".m"], ext):
            # Acceptable sources clang and objc:
            # https://bazel.build/reference/be/c-cpp#cc_library.srcs
            # https://bazel.build/reference/be/objective-c#objc_library.srcs
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

    srcs = sets.to_list(srcs_set)
    others = sets.to_list(others_set)

    # Add each directory that contains a private header to the includes
    private_includes_set = sets.make([
        paths.dirname(src)
        for src in srcs
        if _is_hdr(src)
    ])

    public_includes = sets.to_list(public_includes_set)
    private_includes = sets.to_list(private_includes_set)

    # The apple/swift-crypto package has a CCryptoBoringSSL target that has a
    # modulemap in their include directory, but it only lists the top-level
    # header. The modulemap spec suggests that the header is parsed and all of
    # the referenced headers are included. For now, we will just add the
    # modulemap hdrs to the ones that we have already found.
    if modulemap_orig_path != None:
        mm_hdrs = _get_hdr_paths_from_modulemap(
            repository_ctx,
            modulemap_orig_path,
        )

        # There are modulemaps in the wild (e.g.,
        # https://github.com/1024jp/GzipSwift) that list system headers (i.e.,
        # absolute path to a system header). Filter them out.
        mm_hdrs = lists.compact([
            hdr if not paths.is_absolute(hdr) else None
            for hdr in mm_hdrs
        ])
        mm_hdrs = _remove_prefixes(mm_hdrs, remove_prefix)
        mm_hdrs_set = sets.make(mm_hdrs)
        hdrs_set = sets.union(hdrs_set, mm_hdrs_set)

    hdrs = sets.to_list(hdrs_set)

    # Remove the prefixes before returning the results
    return struct(
        hdrs = sorted(hdrs),
        srcs = sorted(srcs),
        public_includes = sorted(public_includes),
        private_includes = sorted(private_includes),
        modulemap = modulemap,
        others = sorted(others),
    )

def _has_objc_srcs(srcs):
    return lists.contains(srcs, lambda x: x.endswith(".m"))

clang_files = struct(
    has_objc_srcs = _has_objc_srcs,
    is_hdr = _is_hdr,
    is_include_hdr = _is_include_hdr,
    is_public_modulemap = _is_public_modulemap,
    collect_files = _collect_files,
    get_hdr_paths_from_modulemap = _get_hdr_paths_from_modulemap,
)
