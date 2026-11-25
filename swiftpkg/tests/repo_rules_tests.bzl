"""Tests for `repo_rules` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:bazel_target_mods.bzl", "bazel_target_mods")
load("//swiftpkg/internal:pkg_ctxs.bzl", "pkg_ctxs")
load(
    "//swiftpkg/internal:pkginfos.bzl",
    "library_type_kinds",
    "pkginfos",
)
load("//swiftpkg/internal:repo_rules.bzl", "repo_rules")

def _download_artifacts_test(ctx):
    """download_artifacts downloads remote binary artifacts"""
    env = unittest.begin(ctx)

    calls = {"download_and_extract": [], "execute": [], "read": []}

    # buildifier: disable=unused-variable
    def _download_and_extract(url, output, sha256 = "", auth = {}):
        calls["download_and_extract"].append(struct(
            auth = auth,
            output = output,
            sha256 = sha256,
            url = url,
        ))
        return struct(success = True)

    # buildifier: disable=unused-variable
    def _execute(args, environment = {}, quiet = True):
        calls["execute"].append(args)
        return struct(return_code = 0, stdout = "", stderr = "")

    # buildifier: disable=unused-variable
    def _read(path, watch = "auto"):
        calls["read"].append(struct(path = path, watch = watch))
        return ""

    build_file_label = "//some/pkg:BUILD.custom"
    repository_ctx = struct(
        attr = struct(
            build_file = build_file_label,
            netrc = "auth.netrc",
        ),
        download_and_extract = _download_and_extract,
        execute = _execute,
        name = "bzlmodmangled~test_pkg",
        read = _read,
    )

    pkg_info = struct(
        name = "TestPkg",
        path = "",
        products = [],
        targets = [
            struct(
                artifact_download_info = struct(
                    checksum = "abc123",
                    url = "https://example.com/Artifact.zip",
                ),
                path = "remote/archive/Artifact.zip",
                type = "binary",
            ),
            struct(
                artifact_download_info = None,
                path = "Local.xcframework",
                type = "binary",
            ),
            struct(
                artifact_download_info = struct(
                    checksum = "def456",
                    url = "https://example.com/Source.zip",
                ),
                path = "remote/archive/Source.zip",
                type = "regular",
            ),
        ],
        url = "https://github.com/example/test-pkg",
        version = "1.0.0",
    )
    pkg_ctx = struct(pkg_info = pkg_info, bazel_target_mods = [])

    repo_rules.download_artifacts(repository_ctx, pkg_ctx)

    asserts.equals(
        env,
        [struct(path = "auth.netrc", watch = "no")],
        calls["read"],
        "the configured netrc should be read for download auth",
    )
    asserts.equals(
        env,
        [
            struct(
                auth = {},
                output = "remote/archive/Artifact.zip",
                sha256 = "abc123",
                url = "https://example.com/Artifact.zip",
            ),
        ],
        calls["download_and_extract"],
        "only remote binary artifacts should be downloaded",
    )

    return unittest.end(env)

download_artifacts_test = unittest.make(
    _download_artifacts_test,
)

def _gen_build_files_with_build_file_test(ctx):
    """When build_file is set, gen_build_files should use it and skip \
    generation."""
    env = unittest.begin(ctx)

    # Track that template was called with the expected arguments.
    calls = {"file": [], "template": []}

    def _template(path, label):
        calls["template"].append(struct(path = path, label = label))

    # buildifier: disable=unused-variable
    def _file(path, content = "", executable = False, legacy_utf8 = False):
        calls["file"].append(struct(path = path, content = content))

    build_file_label = "//some/pkg:BUILD.custom"
    build_file_content = """\
load("@rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Foo",
    srcs = ["Foo.swift"],
    module_name = "NotATarget",
)

alias(
    name = "Bar",
    actual = ":Foo",
)

alias(name = "Bar", actual = ":Foo")
"""

    # buildifier: disable=unused-variable
    def _read(path, watch = "auto"):
        if path != build_file_label:
            fail("unexpected read: {}".format(path))
        return build_file_content

    repository_ctx = struct(
        attr = struct(
            bazel_target_mods = "",
            build_file = build_file_label,
            system_sdk_deps = True,
            binary_target_deps = True,
        ),
        file = _file,
        read = _read,
        template = _template,
    )

    # Pass None for pkg_ctx. If the early return is bypassed, the function
    # will fail trying to access pkg_ctx.pkg_info, making the failure obvious.
    repo_rules.gen_build_files(repository_ctx, None)

    asserts.equals(
        env,
        1,
        len(calls["template"]),
        "template should be called exactly once",
    )
    asserts.equals(
        env,
        "BUILD.bazel",
        calls["template"][0].path,
        "template output path should be BUILD.bazel",
    )
    asserts.equals(
        env,
        build_file_label,
        calls["template"][0].label,
        "template should receive the build_file label",
    )

    # The names that the custom BUILD file declares, sorted and deduped.
    asserts.equals(env, 1, len(calls["file"]))
    asserts.equals(env, "rspm_targets.json", calls["file"][0].path)
    asserts.equals(
        env,
        {"targets": ["Bar", "Foo"]},
        json.decode(calls["file"][0].content),
    )

    return unittest.end(env)

gen_build_files_with_build_file_test = unittest.make(
    _gen_build_files_with_build_file_test,
)

def _gen_build_files_without_build_file_test(ctx):
    """When build_file is None, gen_build_files should proceed with normal \
    generation."""
    env = unittest.begin(ctx)

    # Track calls to template — it should NOT be called.
    calls = {"file": [], "template": []}

    def _template(path, label):
        calls["template"].append(struct(path = path, label = label))

    # buildifier: disable=unused-variable
    def _file(path, content = "", executable = False, legacy_utf8 = False):
        calls["file"].append(struct(path = path, content = content))

    # buildifier: disable=unused-variable
    def _execute(args, environment = {}, quiet = True):
        # Return empty results for find commands (license file search).
        return struct(return_code = 0, stdout = "", stderr = "")

    repository_ctx = struct(
        attr = struct(bazel_target_mods = "", build_file = None),
        name = "bzlmodmangled~test_pkg",
        template = _template,
        file = _file,
        execute = _execute,
        os = struct(name = "linux"),
    )

    pkg_info = struct(
        name = "TestPkg",
        url = "https://github.com/example/test-pkg",
        version = "1.0.0",
        path = "",
        targets = [],
        products = [],
    )
    pkg_ctx = struct(
        pkg_info = pkg_info,
        system_sdk_deps = True,
        binary_target_deps = True,
        bazel_target_mods = [bazel_target_mods.new(
            bazel_target_mods.verbs.set,
            "package_info.rspm",
            "package_version",
            value = "overridden",
        )],
    )

    repo_rules.gen_build_files(repository_ctx, pkg_ctx)
    asserts.true(env, 'package_version = "overridden"' in calls["file"][-1].content, calls["file"][-1].content)
    asserts.true(
        env,
        'exports_files([\n    "pkg_info.json",\n    "rspm_targets.json",\n])' in calls["file"][-1].content,
        calls["file"][-1].content,
    )
    targets_json = [f for f in calls["file"] if f.path == "rspm_targets.json"]
    asserts.equals(env, 1, len(targets_json))
    asserts.equals(
        env,
        {"targets": ["package_info.rspm"]},
        json.decode(targets_json[0].content),
    )
    asserts.true(env, targets_json[0].content.endswith("}\n"))
    asserts.false(env, 'package_version = "1.0.0"' in calls["file"][-1].content)

    asserts.equals(
        env,
        0,
        len(calls["template"]),
        "template should not be called when build_file is None",
    )

    # Verify that the normal generation path wrote a BUILD file.
    asserts.true(
        env,
        len(calls["file"]) > 0,
        "file should be called to write the generated BUILD file",
    )

    return unittest.end(env)

gen_build_files_without_build_file_test = unittest.make(
    _gen_build_files_without_build_file_test,
)

def _gen_build_files_adds_version_check_in_v2_test(ctx):
    """When slice_dir is set, gen_build_files declares the Swift version \
    check and attaches it to the generated libraries."""
    env = unittest.begin(ctx)

    calls = {"file": []}

    # buildifier: disable=unused-variable
    def _file(path, content = "", executable = False, legacy_utf8 = False):
        calls["file"].append(struct(path = path, content = content))

    # buildifier: disable=unused-variable
    def _execute(args, environment = {}, quiet = True):
        return struct(return_code = 0, stdout = "", stderr = "")

    repository_ctx = struct(
        attr = struct(
            bazel_package_name = "swiftpkg_test_pkg",
            bazel_target_mods = "",
            build_file = None,
            slice_dir = "swift/macos",
        ),
        name = "bzlmodmangled~swiftpkg_test_pkg",
        file = _file,
        execute = _execute,
        os = struct(name = "linux"),
    )

    repo_name = "@swiftpkg_test_pkg"
    pkg_info = pkginfos.new(
        name = "TestPkg",
        path = "",
        tools_version = "5.9",
        url = "https://github.com/example/test-pkg",
        version = "1.0.0",
        products = [
            pkginfos.new_product(
                name = "Foo",
                type = pkginfos.new_product_type(
                    library = pkginfos.new_library_type(
                        library_type_kinds.automatic,
                    ),
                ),
                targets = ["Foo"],
            ),
        ],
        targets = [
            pkginfos.new_target(
                name = "Foo",
                type = "regular",
                c99name = "Foo",
                module_type = "SwiftTarget",
                path = "Sources/Foo",
                sources = ["Foo.swift"],
                dependencies = [],
                repo_name = repo_name,
                swift_src_info = pkginfos.new_swift_src_info(),
            ),
        ],
    )
    pkg_ctx = pkg_ctxs.new(pkg_info = pkg_info, repo_name = repo_name)

    repo_rules.gen_build_files(repository_ctx, pkg_ctx)

    build_files = [f for f in calls["file"] if f.path == "BUILD.bazel"]
    asserts.equals(env, 1, len(build_files))
    content = build_files[0].content
    asserts.true(
        env,
        """\
swift_version_check(
    name = "swift_version_check",
    slice_dir = "swift/macos",
    version_file = "swift_version.txt",
)""" in content,
        content,
    )
    asserts.true(
        env,
        """\
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "swift_version_check")""" in content,
        content,
    )
    asserts.true(
        env,
        'swift_library(\n    name = "Foo.rspm.__impl",' in content,
        content,
    )
    asserts.true(
        env,
        '    data = [":swift_version_check"],' in content,
        content,
    )

    targets_json = [f for f in calls["file"] if f.path == "rspm_targets.json"]
    asserts.equals(env, 1, len(targets_json))
    asserts.true(
        env,
        "swift_version_check" in json.decode(targets_json[0].content)["targets"],
        targets_json[0].content,
    )

    return unittest.end(env)

gen_build_files_adds_version_check_in_v2_test = unittest.make(
    _gen_build_files_adds_version_check_in_v2_test,
)

def _make_files_read_only_test(ctx):
    env = unittest.begin(ctx)

    calls = []

    def execute(args, quiet = False):
        calls.append(struct(args = args, quiet = quiet))
        return struct(
            return_code = 0,
            stdout = "",
            stderr = "",
        )

    repository_ctx = struct(
        execute = execute,
        os = struct(name = "linux"),
    )

    repo_rules.make_files_read_only(
        repository_ctx,
        "/tmp/swiftpkg",
        enabled = True,
    )

    asserts.equals(env, 1, len(calls), "expected a single chmod invocation")
    asserts.equals(
        env,
        [
            "find",
            "/tmp/swiftpkg",
            "-type",
            "f",
            "-exec",
            "chmod",
            "a-w",
            "{}",
            "+",
        ],
        calls[0].args,
        "expected the repository files to be marked read-only",
    )
    asserts.true(env, calls[0].quiet, "expected chmod invocation to be quiet")

    return unittest.end(env)

make_files_read_only_test = unittest.make(_make_files_read_only_test)

def _make_files_read_only_disabled_noop_test(ctx):
    env = unittest.begin(ctx)

    calls = []

    def execute(args, quiet = False):
        calls.append(struct(args = args, quiet = quiet))
        return struct(
            return_code = 0,
            stdout = "",
            stderr = "",
        )

    repository_ctx = struct(
        execute = execute,
    )

    repo_rules.make_files_read_only(
        repository_ctx,
        "/tmp/swiftpkg",
        enabled = False,
    )

    asserts.equals(env, [], calls, "expected no chmod invocation when disabled")

    return unittest.end(env)

make_files_read_only_disabled_noop_test = unittest.make(
    _make_files_read_only_disabled_noop_test,
)

def _v2_attrs_error_test(ctx):
    env = unittest.begin(ctx)

    def _attr(dump_manifest = None, desc_manifest = None, swift_version = None, slice_dir = ""):
        return struct(
            dump_manifest = dump_manifest,
            desc_manifest = desc_manifest,
            swift_version = swift_version,
            slice_dir = slice_dir,
        )

    # v1: nothing set.
    asserts.equals(env, None, repo_rules.v2_attrs_error("foo", _attr()))

    # v2: everything set.
    asserts.equals(env, None, repo_rules.v2_attrs_error("foo", _attr(
        dump_manifest = "d",
        desc_manifest = "e",
        swift_version = "s",
        slice_dir = "swift/macos",
    )))

    asserts.equals(
        env,
        "`foo` sets `slice_dir` but not `dump_manifest`; a v2 slice " +
        "package needs both.",
        repo_rules.v2_attrs_error("foo", _attr(slice_dir = "swift/macos")),
    )
    asserts.equals(
        env,
        "`foo` sets `dump_manifest` but not: desc_manifest, swift_version, slice_dir.",
        repo_rules.v2_attrs_error("foo", _attr(dump_manifest = "d")),
    )

    return unittest.end(env)

v2_attrs_error_test = unittest.make(_v2_attrs_error_test)

def repo_rules_test_suite():
    return unittest.suite(
        "repo_rules_tests",
        download_artifacts_test,
        gen_build_files_adds_version_check_in_v2_test,
        gen_build_files_with_build_file_test,
        gen_build_files_without_build_file_test,
        make_files_read_only_disabled_noop_test,
        make_files_read_only_test,
        v2_attrs_error_test,
    )
