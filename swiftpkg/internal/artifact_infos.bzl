"""Module for creating artifact infos for xcframeworks."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(":repository_files.bzl", "repository_files")

def _new_framework_info(path, link_type):
    """Create a `struct` representing an Apple framework.

    Args:
        path: The path to the `XXX.framework` directory as a `string`.
        link_type: A `string` specifying whether the framework should be
            dynamically linked (`dynamic`) or statically linked (`static`).

    Returns:
        A `struct` representing an Apple framework.
    """
    return struct(
        artifiact_type = artifact_types.framework,
        path = path,
        link_type = link_type,
    )

def _new_xcframework_info(path, framework_infos):
    """Create a `struct` representing an Apple xcframework.

    Args:
        path: The path to the expanded `XXX.xcframework` directory as a
            `string`.
        framework_infos: A `list` of framework info `struct` values as created by
            `artifact_infos.new_framework_info`.

    Returns:
        A `struct` representing an Apple xcframework.
    """
    link_type = link_types.unknown
    if len(framework_infos) > 0:
        framework_info = framework_infos[0]
        link_type = framework_info.link_type
    return struct(
        artifiact_type = artifact_types.xcframework,
        path = path,
        framework_infos = framework_infos,
        link_type = link_type,
    )

def _framework_name_from_path(path):
    """Determine the framework name from the provided path.

    Args:
        path: The path to the `XXX.framework` directory as a `string`.

    Returns:
        The framework name as a `string`.
    """
    basename = paths.basename(path)
    (name, ext) = paths.split_extension(basename)
    if ext != ".framework":
        fail("""\
The path does not point to an Apple framework. Please file a bug at \
https://github.com/cgrindel/rules_swift_package_manager/issues/new/choose. path: {}\
""".format(path))
    return name

def _new_framework_info_from_files(repository_ctx, path):
    """Create a `struct` representing an Apple framework from the files at the \
    specified path.

    Args:
        repository_ctx: A `repository_ctx` instance.
        path: The path to the expanded `XXX.framework` directory as a `string`.

    Returns:
        A `struct` representing an Apple framework as returned by
        `artifact_infos.new_framework_info()`.
    """
    framework_name = _framework_name_from_path(path)

    # Frameworks have a structure like the following:
    # XXX.framework
    #   └─ Headers (dir)
    #   └─ Modules (dir)
    #   └─ XXX (binary file)
    #   └─ Info.plist (XML file)
    binary_files = repository_files.list_files_under(
        repository_ctx,
        path,
        by_name = framework_name,
        depth = 1,
    )
    if len(binary_files) == 0:
        fail("No binary files were found for framework at {}".format(path))
    link_type = _link_type(repository_ctx, binary_files[0])

    return _new_framework_info(
        path = path,
        link_type = link_type,
    )

def _link_type(repository_ctx, path):
    """Determine the link type for the framework binary file.

    Args:
        repository_ctx: A `repository_ctx` instance.
        path: The path to a framework binary file under a `XXX.framework`
            directory as a `string`.

    Returns:
        The link type for the framework as a `string`.
    """
    file_type = repository_files.file_type(repository_ctx, path)

    # static Examples:
    #   current ar archive random library
    #   current ar archive
    # dynamic Examples:
    #   dynamically linked shared library
    if file_type.find("ar archive") >= 0:
        link_type = link_types.static
    elif file_type.find("dynamic") >= 0:
        link_type = link_types.dynamic
    else:
        link_type = link_types.unknown
    return link_type

def _new_xcframework_info_from_files(repository_ctx, path):
    """Return a `struct` descrbing an xcframework from the files at the \
    specified path.

    Args:
        repository_ctx: A `repository_ctx` instance.
        path: The path to the expanded `XXX.xcframework` directory as a
            `string`.

    Returns:
        A `struct` describing the xcframework as returned by
        `artifact_infos.new_xcframework_info()`.
    """

    # XC Frameworks have a structure like the following:
    # XXX.xcframework
    #   └─ ios-arm64/XXX.framework
    #   └─ ios-arm64_x86_64-maccatalyst/XXX.framework
    #   └─ macos-arm64_x86_64/XXX.framework
    framework_paths = repository_files.list_directories_under(
        repository_ctx,
        path,
        by_name = "*.framework",
        depth = 2,
    )
    framework_infos = [
        _new_framework_info_from_files(repository_ctx, fp)
        for fp in framework_paths
    ]
    return _new_xcframework_info(
        path = path,
        framework_infos = framework_infos,
    )

artifact_infos = struct(
    new_framework_info = _new_framework_info,
    new_xcframework_info = _new_xcframework_info,
    new_xcframework_info_from_files = _new_xcframework_info_from_files,
    link_type = _link_type,
)

link_types = struct(
    dynamic = "dynamic",
    static = "static",
    unknown = "unknown",
)

artifact_types = struct(
    framework = "framework",
    xcframework = "xcframework",
)
