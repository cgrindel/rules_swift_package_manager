"""Module containing shared definitions and functions for repository rules."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:versions.bzl", "versions")
load(":build_files.bzl", "build_files")
load(":repository_files.bzl", "repository_files")
load(":spm_versions.bzl", "spm_versions")
load(":swiftpkg_build_files.bzl", "swiftpkg_build_files")

_swift_attrs = {
    "bazel_package_name": attr.string(
        doc = "The short name for the Swift package's Bazel repository.",
    ),
    "dependencies_index": attr.label(
        doc = """\
A JSON file that contains a mapping of Swift products and Swift modules.\
""",
        mandatory = True,
    ),
}

_env_attrs = {
    "env": attr.string_dict(
        doc = """\
Environment variables that will be passed to the execution environments for \
this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM \
package description generation)\
""",
    ),
}

_DEVELOPER_DIR_ENV = "DEVELOPER_DIR"

def _get_exec_env(repository_ctx):
    """Creates a `dict` of environment variables which will be past to all execution environments for this rule.

    Args:
        repository_ctx: A `repository_ctx` instance.

    Returns:
        A `dict` of environment variables which will be used for execution environments for this rule.
    """

    # If the DEVELOPER_DIR is specified in the environment, it will override
    # the value which may be specified in the env attribute.
    env = dicts.add(repository_ctx.attr.env)
    dev_dir = repository_ctx.os.environ.get(_DEVELOPER_DIR_ENV)
    if dev_dir:
        env[_DEVELOPER_DIR_ENV] = dev_dir
    return env

def _check_spm_version(repository_ctx, env = {}):
    min_spm_ver = "5.4.0"
    spm_ver = spm_versions.get(repository_ctx, env = env)
    if not versions.is_at_least(threshold = min_spm_ver, version = spm_ver):
        fail("""\
`rules_swift_package_manager` requires that Swift Package Manager be version %s or \
higher. Found version %s installed.\
""" % (min_spm_ver, spm_ver))

def _gen_build_files(repository_ctx, pkg_ctx):
    pkg_info = pkg_ctx.pkg_info

    # Create Bazel declarations for the Swift package targets
    bld_files = []
    for target in pkg_info.targets:
        # Unfortunately, Package.resolved does not contain test-only external
        # dependencies. So, we need to skip generating test targets. If a target
        # does not have any product memberships, it is a testonly
        if target.type == "test" or len(target.product_memberships) == 0:
            continue
        if target.artifact_download_info != None:
            _download_artifact(repository_ctx, target.artifact_download_info, target.path)
        bld_file = swiftpkg_build_files.new_for_target(repository_ctx, pkg_ctx, target)
        if bld_file == None:
            continue
        bld_files.append(bld_file)

    # Create Bazel declarations for the targets
    bld_files.append(swiftpkg_build_files.new_for_products(pkg_info, pkg_ctx.repo_name))

    # Write the build file
    root_bld_file = build_files.merge(*bld_files)
    build_files.write(repository_ctx, root_bld_file, pkg_info.path)

def _write_workspace_file(repository_ctx, repoDir):
    path = paths.join(repoDir, "WORKSPACE")
    repo_name = repository_ctx.name
    content = """\
workspace(name = "{}")
""".format(repo_name)
    repository_ctx.file(path, content = content, executable = False)

# TODO(chuck): Remove _new_file_info.

def _new_file_info(path, file_output):
    """Create a `struct` representing info about a file.

    Args:
        path: The path to the file as a `string`. This could be relative or
            absolute depending upon the context.
        file_output: The output of running `file <path>` as a `string`.

    Returns:
    """
    return struct(
        path = path,
        file_output = file_output,
    )

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
        path = path,
        link_type = link_type,
    )

def _framework_name_from_path(path):
    basename = paths.basename(path)
    (name, _ext) = paths.split_extension(basename)
    return name

def _new_framework_info_from_files(repository_ctx, path):
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

    # DEBUG BEGIN
    print("*** CHUCK binary_files: ")
    for idx, item in enumerate(binary_files):
        print("*** CHUCK", idx, ":", item)

    # DEBUG END
    if len(binary_files) == 0:
        fail("No binary files were found for framework at {}".format(path))
    file_type = repository_files.file_type(repository_ctx, binary_files[0])

    # DEBUG BEGIN
    print("*** CHUCK file_type:\n", file_type)

    # DEBUG END
    if file_type.find("ar archive random library") > 0:
        link_type = link_types.static
    elif file_type.find("dynamically linked shared library"):
        link_type = link_types.dynamic
    else:
        link_type = link_types.unknown
    return _new_framework_info(
        path = path,
        link_type = link_type,
    )

def _new_xcframework_info(path, framework_infos):
    """Create a `struct` representing an Apple xcframework.

    Args:
        path: The path to the expanded `XXX.xcframework` directory as a
            `string`.
        framework_infos: A `list` of framework info `struct` values as created by
            `repo_rules.new_framework_info`.

    Returns:
        A `struct` representing an xcframework.
    """
    return struct(
        artifiact_type = "xcframework",
        path = path,
        framework_infos = framework_infos,
    )

def _new_xcframework_info_from_files(repository_ctx, path):
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

def _download_artifact(repository_ctx, artifact_download_info, path):
    result = repository_ctx.download_and_extract(
        url = artifact_download_info.url,
        output = path,
        sha256 = artifact_download_info.checksum,
    )
    if not result.success:
        fail("Failed to download artifact. url: {url}, sha256: {sha256}".format(
            url = artifact_download_info.url,
            sha256 = artifact_download_info.checksum,
        ))

    # DEBUG BEGIN
    print("*** CHUCK ==============")
    print("*** CHUCK repository_ctx.name: ", repository_ctx.name)
    print("*** CHUCK artifact_download_info.url: ", artifact_download_info.url)
    print("*** CHUCK path: ", path)
    print("*** CHUCK result: ", result)

    # DEBUG END

    # Collect artifact info about contents of the downloaded artifact
    xcframework_dirs = repository_files.list_directories_under(
        repository_ctx,
        path,
        max_depth = 1,
        by_name = "*.xcframework",
    )

    # DEBUG BEGIN
    print("*** CHUCK xcframework_dirs: ")
    for idx, item in enumerate(xcframework_dirs):
        print("*** CHUCK", idx, ":", item)

    # DEBUG END

    return [
        _new_xcframework_info_from_files(repository_ctx, xf)
        for xf in xcframework_dirs
    ]

    # Check for XXX.xcframework under path
    # Look for files names XXX under the path/XXX.xcframework directory.
    # Execute `file` on the files that are found.
    # Return struct OR list of structs with location of XXX.xcframework and `file` info for each of the XXX files.

repo_rules = struct(
    check_spm_version = _check_spm_version,
    env_attrs = _env_attrs,
    gen_build_files = _gen_build_files,
    get_exec_env = _get_exec_env,
    new_file_info = _new_file_info,
    new_xcframework_info = _new_xcframework_info,
    swift_attrs = _swift_attrs,
    write_workspace_file = _write_workspace_file,
)

link_types = struct(
    unknown = "unknown",
    static = "static",
    dynamic = "dynamic",
)
