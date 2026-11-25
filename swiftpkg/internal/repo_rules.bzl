"""Module containing shared definitions and functions for repository rules."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "read_netrc", "read_user_netrc", "use_netrc")
load(":artifact_infos.bzl", "artifact_infos")
load(":bazel_target_mods.bzl", "bazel_target_mods")
load(":build_decls.bzl", "build_decls")
load(":build_files.bzl", "build_files")
load(":load_statements.bzl", "load_statements")
load(":manifest_files.bzl", "manifest_files")
load(":pkginfos.bzl", "target_types")
load(":repository_files.bzl", "repository_files")
load(":repository_utils.bzl", "repository_utils")
load(":starlark_codegen.bzl", scg = "starlark_codegen")
load(":swift_version_checks.bzl", "swift_version_checks")
load(
    ":swiftpkg_build_files.bzl",
    "swiftpkg_build_defs_location",
    "swiftpkg_build_files",
)

_swift_attrs = {
    "bazel_package_name": attr.string(
        doc = "The short name for the Swift package's Bazel repository.",
    ),
    "bazel_target_mods": attr.string(
        doc = """\
A JSON `string` describing buildozer-style modifications that are applied to \
the declarations in the generated `BUILD.bazel` file. Set by the \
`swift_deps.bazel_target_set_*`, `swift_deps.bazel_target_set_select_*`, \
`swift_deps.bazel_target_add` and `swift_deps.bazel_target_add_select` tags; \
direct users should prefer that typed API.\
""",
    ),
    "binary_target_deps": attr.bool(
        default = False,
        doc = "Effective binary-target dependency inference setting. Reserved; does not generate dependencies yet.",
    ),
    "dep_module_aliases": attr.string(
        doc = """\
A JSON string mapping package identities to their module alias mappings \
(SE-0339), e.g. `{"swift-log": {"Logging": "SwiftLog"}}`. A Swift target in \
this package is compiled with `-module-alias <key>=<value>` for the aliases \
of every package identity this package directly depends on, so its sources \
can keep importing the original module name. Set by the `swift_deps` bzlmod \
extension from the aliases declared in the root package manifest.\
""",
    ),
    "module_aliases": attr.string_dict(
        doc = """\
Mapping of Swift module names defined by this package to replacement module \
names (SE-0339). A Swift target whose module name matches a key is compiled \
with the value as its module name, and every generated Swift target in this \
package is compiled with `-module-alias <key>=<value>` so package sources \
can keep importing the original name. Bazel targets outside the package \
graph must import the replacement name. Use this to resolve module name \
collisions with same-named modules elsewhere in the build (e.g. when using \
explicit module maps).\
""",
    ),
    "package_repos": attr.label(
        doc = """\
A JSON file listing the Bazel repository names of every Swift package declared \
alongside this one (`{"repo_names": [...]}`). When set, this package's \
generated targets build against the highest minimum OS version found among \
the package's own platform declarations and the effective versions of the \
packages it depends on, matching `swift build`. Set by the `swift_deps` bzlmod \
extension; when unset only the package's own declarations are used.\
""",
    ),
    "system_sdk_deps": attr.bool(
        default = False,
        doc = "Effective SDK dependency inference setting. Reserved; does not generate dependencies yet.",
    ),
    "target_deps": attr.string_list_dict(
        doc = """\
Additional dependencies to add to generated targets. Keys are Swift package \
target names, which are mapped to generated implementation target names. If a \
key already contains `.rspm`, it is matched as a generated target name \
unchanged. Values may be Bazel label strings or Swift package target names. \
Bare value strings and local label strings such as `OtherTarget` or \
`:OtherTarget` are mapped to generated target labels such as \
`:OtherTarget.rspm` when they match Swift package targets in the same \
generated BUILD package. Values that contain `.rspm`, external labels, \
cross-package labels, and local labels that do not match package targets are \
emitted unchanged.\
""",
    ),
}

_slice_attrs = {
    "desc_manifest": attr.label(
        allow_single_file = True,
        mandatory = True,
        doc = """\
The cached `swift package describe` JSON (`desc.json`) for this package in \
the slice.\
""",
    ),
    "dump_manifest": attr.label(
        allow_single_file = True,
        mandatory = True,
        doc = """\
The cached `swift package dump-package` JSON (`dump.json`) for this package \
in the slice. The package is read from the cached manifests; Swift Package \
Manager never runs while Bazel loads.\
""",
    ),
    "slice_dir": attr.string(
        mandatory = True,
        doc = """\
The workspace-relative slice directory, used in the Swift version check \
message.\
""",
    ),
    "swift_version": attr.label(
        allow_single_file = True,
        mandatory = True,
        doc = """\
The slice's `swift_version.txt`, the Swift version the manifests were cached \
with.\
""",
    ),
}

def _read_manifests(repository_ctx):
    """Reads the slice's cached manifests for this package.

    Args:
        repository_ctx: A `repository_ctx` instance.

    Returns:
        A `struct` with `dump_manifest` and `desc_manifest` as decoded `dict`
        values.
    """
    attr = repository_ctx.attr

    def _read(label):
        value = manifest_files.read_json(repository_ctx, label)
        if value == None:
            fail("""\
The cached manifest {label} is missing or malformed. Run \
`bazel run @swift_package//:cache` to regenerate it.\
""".format(label = label))
        return value

    return struct(
        dump_manifest = _read(attr.dump_manifest),
        desc_manifest = _read(attr.desc_manifest),
    )

def _copy_swift_version(repository_ctx):
    """Copies the slice's `swift_version.txt` to the repository root.

    Args:
        repository_ctx: A `repository_ctx` instance.
    """
    repository_utils.copy(
        repository_ctx,
        repository_ctx.attr.swift_version,
        "swift_version.txt",
    )

def _download_artifacts(repository_ctx, pkg_ctx):
    for target in pkg_ctx.pkg_info.targets:
        if target.type == target_types.binary and target.artifact_download_info != None:
            url = target.artifact_download_info.url
            auth = _get_auth(repository_ctx, [url])
            artifact_download_info = target.artifact_download_info

            result = repository_ctx.download_and_extract(
                url = url,
                output = target.path,
                sha256 = artifact_download_info.checksum,
                auth = auth,
            )

            if not result.success:
                fail("Failed to download artifact. url: {url}, sha256: {sha256}".format(
                    url = artifact_download_info.url,
                    sha256 = artifact_download_info.checksum,
                ))

def _gen_build_files(repository_ctx, pkg_ctx):
    if repository_ctx.attr.build_file:
        if repository_ctx.attr.bazel_target_mods:
            fail("""\
`bazel_target_mods` cannot be used with `build_file` because the complete \
BUILD file override bypasses generated declarations.\
""")

        # Use template() with no substitutions to copy the file. There is
        # no direct copy API for label-referenced files in repository rules.
        repository_ctx.template("BUILD.bazel", repository_ctx.attr.build_file)

        # An alias repository over this package aliases the names that the
        # custom BUILD file declares literally.
        _write_targets_json(
            repository_ctx,
            _declared_names(repository_ctx.read(repository_ctx.attr.build_file)),
            "",
        )
        return

    pkg_info = pkg_ctx.pkg_info

    bld_files = []

    licenses = repository_files.find_license_files(repository_ctx)
    bld_files.append(
        # Pick the shortest name, in order to prefer `LICENSE` over
        # `LICENSE.md`
        swiftpkg_build_files.new_for_license(
            pkg_info,
            sorted(licenses, key = len)[0] if licenses else None,
        ),
    )

    # Create Bazel declarations for the Swift package targets
    for target in pkg_info.targets:
        # Unfortunately, Package.resolved does not contain test-only external
        # dependencies. So, we need to skip generating test targets.
        if target.type == "test":
            continue

        artifact_infos = []
        if target.type == target_types.binary:
            artifact_infos = _artifact_infos_from_path(
                repository_ctx,
                target.path,
            )

        bld_file = swiftpkg_build_files.new_for_target(
            repository_ctx,
            pkg_ctx,
            target,
            artifact_infos,
        )

        if bld_file == None:
            continue
        bld_files.append(bld_file)

    # Create Bazel declarations for the targets
    bld_files.append(swiftpkg_build_files.new_for_products(pkg_ctx))

    # Export the list of the root BUILD file's targets.
    exports_files = scg.new_fn_call("exports_files", ["rspm_targets.json"])
    bld_files.append(build_files.new(decls = [exports_files]))

    # Write the build file
    root_bld_file = build_files.merge(*bld_files)

    # Apply the root module's buildozer-style modifications last, so that they
    # see every generated declaration and always win over generated values.
    if pkg_ctx.bazel_target_mods:
        root_bld_file = build_files.new(
            load_stmts = root_bld_file.load_stmts,
            package_attrs = root_bld_file.package_attrs,
            decls = bazel_target_mods.apply(
                root_bld_file.decls,
                pkg_ctx.bazel_target_mods,
            ),
        )

    # The slice carries the Swift version its manifests were cached with.
    # Every generated library, binary and test depends on the check, so a
    # build with a different Swift fails with a message naming the slice.
    root_bld_file = build_files.new(
        load_stmts = load_statements.uniq(
            root_bld_file.load_stmts + [load_statements.new(
                swiftpkg_build_defs_location,
                swift_version_checks.name,
            )],
        ),
        package_attrs = root_bld_file.package_attrs,
        decls = build_decls.uniq(
            swift_version_checks.attach(root_bld_file.decls) +
            [swift_version_checks.decl(repository_ctx.attr.slice_dir)],
        ),
    )
    _write_targets_json(
        repository_ctx,
        [d.name for d in root_bld_file.decls if d.kind != "_function"],
        pkg_info.path,
    )
    build_files.write(repository_ctx, root_bld_file, pkg_info.path)

_NAME_PREFIX = 'name = "'

def _declared_names(content):
    """Collects the target names that a BUILD file declares literally.

    Every `name = "<x>"` is a name, unless a longer identifier ends in `name`
    (e.g., `module_name = "<x>"`). Names that a macro computes are not seen.

    Args:
        content: The BUILD file content as a `string`.

    Returns:
        A sorted `list` of unique names.
    """
    names = {}
    chunks = content.split(_NAME_PREFIX)
    for i in range(1, len(chunks)):
        # Only accept `name` as a standalone attribute, not a suffix.
        before = chunks[i - 1]
        if before and before[-1] not in " \t\r\n(,":
            continue
        chunk = chunks[i]
        end = chunk.find('"')
        if end > 0:
            names[chunk[:end]] = None
    return sorted(names.keys())

def _write_targets_json(repository_ctx, names, path):
    """Writes the names of the root BUILD file's targets to `rspm_targets.json`.

    An alias repository reads this file to learn which targets to alias.
    """
    content = json.encode_indent({"targets": sorted(names)}, indent = "  ")
    repository_ctx.file(
        paths.join(path, "rspm_targets.json"),
        content = content + "\n",
        executable = False,
    )

def _write_workspace_file(repository_ctx, repoDir):
    path = paths.join(repoDir, "WORKSPACE")
    repo_name = repository_ctx.name
    content = """\
workspace(name = "{}")
""".format(repo_name)
    repository_ctx.file(path, content = content, executable = False)

def _make_files_read_only(repository_ctx, directory, enabled):
    if not enabled:
        return

    exec_result = repository_ctx.execute(
        [
            "find",
            directory,
            "-type",
            "f",
            "-exec",
            "chmod",
            "a-w",
            "{}",
            "+",
        ],
        quiet = True,
    )
    if exec_result.return_code != 0:
        fail("""\
Failed to mark repository files as read-only. directory: {directory}
{stderr}\
""".format(
            directory = directory,
            stderr = exec_result.stderr,
        ))

def _artifact_infos_from_path(repository_ctx, path):
    if path.endswith(".xcframework"):
        xcframework_dirs = [path]
    else:
        # Collect artifact info about contents of the downloaded artifact
        xcframework_dirs = repository_files.list_directories_under(
            repository_ctx,
            path,
            by_name = "*.xcframework",
        )

    # NOTE: SPM validates the `.xcframework` paths by decoding the `Info.plist` file.
    # This would be more involved to do in Starlark, so instead we'll assume
    # that a `.xcframework` dir is a potential candidate if it contains a
    # `Info.plist` file without checking the file contents.
    # See: https://github.com/swiftlang/swift-package-manager/blob/c26c12f54357fb7246c0bdbe3483105389f056b8/Sources/Workspace/Workspace%2BBinaryArtifacts.swift#L771-L780
    xcframework_dirs = [
        xf
        for xf in xcframework_dirs
        if repository_files.path_exists(repository_ctx, paths.join(xf, "Info.plist"))
    ]

    # If multiple found, use the last one which is what SPM currently does:
    # https://github.com/swiftlang/swift-package-manager/blob/c26c12f54357fb7246c0bdbe3483105389f056b8/Sources/Workspace/Workspace%2BBinaryArtifacts.swift#L699-L723
    if len(xcframework_dirs) > 1:
        # buildifier: disable=print
        print("""\
WARNING: Found multiple XCFramework binary artifacts in the downloaded artifact: \
{xcframework_dirs}, using the last one.
""".format(
            xcframework_dirs = xcframework_dirs,
        ))
        xcframework_dirs = xcframework_dirs[-1:]

    return [
        artifact_infos.new_xcframework_info_from_files(repository_ctx, xf)
        for xf in xcframework_dirs
    ]

# Copied from "@bazel_tools//tools/build_defs/repo:utils.bzl". Availaible starting with 7.1.0
def _get_auth(ctx, urls):
    """Utility function to obtain the correct auth dict for a list of urls from .netrc file.

    Support optional netrc and auth_patterns attributes if available.

    Args:
      ctx: The repository context of the repository rule calling this utility
        function.
      urls: the list of urls to read

    Returns:
      the auth dict which can be passed to repository_ctx.download
    """
    if hasattr(ctx.attr, "netrc") and ctx.attr.netrc:
        netrc = read_netrc(ctx, ctx.attr.netrc)
    elif "NETRC" in ctx.os.environ:
        netrc = read_netrc(ctx, ctx.os.environ["NETRC"])
    else:
        netrc = read_user_netrc(ctx)
    auth_patterns = {}
    if hasattr(ctx.attr, "auth_patterns") and ctx.attr.auth_patterns:
        auth_patterns = ctx.attr.auth_patterns
    return use_netrc(netrc, urls, auth_patterns)

def _remove_bazel_files(repository_ctx, directory):
    files = ["BUILD.bazel", "BUILD", "WORKSPACE", "WORKSPACE.bazel"]
    for file in files:
        repository_files.find_and_delete_files(repository_ctx, directory, file)

def _remove_swift_version_file(repository_ctx, directory):
    # A `.swift-version` file in the package root can hijack Swift toolchain
    # proxies (e.g. `swiftly`) into requiring a version that isn't installed.
    # https://github.com/swiftlang/swiftly/issues/504
    repository_ctx.delete(paths.join(directory, ".swift-version"))

def _remove_modulemaps(repository_ctx, directory, targets):
    repository_files.find_and_delete_files(
        repository_ctx,
        directory,
        "module.modulemap",
        exclude_paths = [
            # xcframeworks that vendor libraries can also contain modulemaps
            "**/*.xcframework/*",
            # Framework modulemaps don't cause issues, and are needed
            "**/*.framework/*",
        ] + [
            # We need to leave any modulemaps that we are passing into
            # `objc_library`
            target.clang_src_info.modulemap_path
            for target in targets
            if target.clang_src_info and target.clang_src_info.modulemap_path
        ],
    )

repo_rules = struct(
    copy_swift_version = _copy_swift_version,
    declared_names = _declared_names,
    download_artifacts = _download_artifacts,
    gen_build_files = _gen_build_files,
    make_files_read_only = _make_files_read_only,
    read_manifests = _read_manifests,
    remove_bazel_files = _remove_bazel_files,
    remove_modulemaps = _remove_modulemaps,
    remove_swift_version_file = _remove_swift_version_file,
    swift_attrs = _swift_attrs,
    slice_attrs = _slice_attrs,
    write_workspace_file = _write_workspace_file,
)
