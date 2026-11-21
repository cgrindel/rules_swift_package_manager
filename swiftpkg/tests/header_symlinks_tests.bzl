"""Tests for `header_symlinks` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:header_symlinks.bzl", "header_symlinks")

_ROOT = "/repo"

def _entry(path, target = None, is_dir = False):
    realpath = None
    if target != None:
        realpath = target if target.startswith("/") else _ROOT + "/" + target
    return header_symlinks.new_entry(path, realpath = realpath, is_dir = is_dir)

def _link(path, target):
    return header_symlinks.new_link(path, target)

def _select_links_test(ctx):
    env = unittest.begin(ctx)

    entries = [
        _entry("A/X.h", "B/X.h"),
        # Points outside the package.
        _entry("A/Outside.h", "/elsewhere/Outside.h"),
        # A sibling directory whose name shares the root as a prefix.
        _entry("A/Sibling.h", "/repo-other/Sibling.h"),
        # Directory symlink.
        _entry("include/Foo.h", "Sources/Foo/include", is_dir = True),
        # Broken symlink.
        _entry("A/Broken.h", None),
        # Inside an XCFramework.
        _entry(
            "Lib.xcframework/ios-arm64/Lib.framework/Headers/Lib.h",
            "Lib.xcframework/ios-arm64/Lib.framework/Versions/A/Headers/Lib.h",
        ),
        # Inside a framework.
        _entry("Lib.framework/Headers/Lib.h", "Lib.framework/Versions/A/Headers/Lib.h"),
        # Points into a framework.
        _entry("include/Lib.h", "Lib.framework/Versions/A/Headers/Lib.h"),
        # Not a header.
        _entry("A/X.m", "B/X.m"),
        _entry("Lib.xcframework", "Framework/Lib.xcframework", is_dir = True),
    ]
    expected = [_link("A/X.h", "B/X.h")]
    asserts.equals(env, expected, header_symlinks.select_links(_ROOT, entries))
    asserts.equals(env, expected, header_symlinks.select_links(_ROOT + "/", entries))

    return unittest.end(env)

select_links_test = unittest.make(_select_links_test)

def _select_links_chain_test(ctx):
    env = unittest.begin(ctx)

    # A/X.h -> B/X.h -> C/X.h. Both symlinks resolve to the final target.
    entries = [
        _entry("B/X.h", "C/X.h"),
        _entry("A/X.h", "C/X.h"),
    ]
    asserts.equals(
        env,
        [_link("A/X.h", "C/X.h"), _link("B/X.h", "C/X.h")],
        header_symlinks.select_links(_ROOT, entries),
    )

    return unittest.end(env)

select_links_chain_test = unittest.make(_select_links_chain_test)

def _select_links_deterministic_test(ctx):
    env = unittest.begin(ctx)

    entries = [
        _entry("Z/X.h", "B/X.h"),
        _entry("A/X.h", "B/X.h"),
        _entry("M/W.h", "N/W.h"),
        _entry("C/X.h", "B/X.h"),
    ]
    reversed_entries = reversed(entries)
    links = header_symlinks.select_links(_ROOT, entries)
    asserts.equals(env, links, header_symlinks.select_links(_ROOT, reversed_entries))
    asserts.equals(
        env,
        ["A/X.h", "C/X.h", "M/W.h", "Z/X.h"],
        [link.path for link in links],
    )

    return unittest.end(env)

select_links_deterministic_test = unittest.make(_select_links_deterministic_test)

def _warning_test(ctx):
    env = unittest.begin(ctx)

    actual = header_symlinks.warning("swiftpkg_msgpack_objective_c", 11)
    asserts.equals(
        env,
        "WARNING: swiftpkg_msgpack_objective_c has 11 header symlinks (listed in " +
        "rspm_header_symlinks.txt) that remote execution duplicates; set " +
        "header_symlinks = \"replace\" (or \"ignore\") with " +
        "swift_deps.configure_package.",
        actual,
    )

    actual = header_symlinks.warning("swiftpkg_ably_cocoa", 1)
    asserts.true(env, actual.startswith("WARNING: swiftpkg_ably_cocoa has 1 header symlink (listed"), actual)

    actual = header_symlinks.warning("swiftpkg_local", 2, local = True)
    asserts.equals(
        env,
        "WARNING: swiftpkg_local has 2 header symlinks (listed in " +
        "rspm_header_symlinks.txt) that remote execution duplicates; " +
        "rules_swift_package_manager does not modify local packages, so " +
        "replace them with forwarding headers in the source, or set " +
        "header_symlinks = \"ignore\" with swift_deps.configure_package.",
        actual,
    )

    actual = header_symlinks.warning("swiftpkg_foo", 3, has_build_file = True)
    asserts.true(env, "has 3 header symlinks" in actual, actual)
    asserts.true(env, "has no effect with build_file" in actual, actual)

    # Every variant is a single line.
    for local in [False, True]:
        for has_build_file in [False, True]:
            for count in [1, 11]:
                actual = header_symlinks.warning(
                    "swiftpkg_foo",
                    count,
                    local = local,
                    has_build_file = has_build_file,
                )
                asserts.false(env, "\n" in actual, actual)

    return unittest.end(env)

warning_test = unittest.make(_warning_test)

def _links_for_target_test(ctx):
    env = unittest.begin(ctx)

    links = [
        _link("Source/PrivateHeaders/Ably/ARTSRWebSocket.h", "Source/SocketRocket/ARTSRWebSocket.h"),
        _link("Source/include/Ably/Public.h", "Source/Public.h"),
        _link("Other/X.h", "Other/Y.h"),
        _link("Shared/Z.h", "Shared/W.h"),
    ]
    actual = header_symlinks.links_for_target(
        reversed(links),
        "Source",
        public_includes = ["Source/include"],
        private_includes = ["Source/PrivateHeaders/Ably", "Shared"],
    )
    asserts.equals(env, [links[1]], actual.hdrs)
    asserts.equals(env, [links[3], links[0]], actual.srcs)

    # A target at the package root owns every symlink.
    actual = header_symlinks.links_for_target(links, ".")
    asserts.equals(env, [], actual.hdrs)
    asserts.equals(
        env,
        ["Other/X.h", "Shared/Z.h", "Source/PrivateHeaders/Ably/ARTSRWebSocket.h", "Source/include/Ably/Public.h"],
        [link.path for link in actual.srcs],
    )

    # A directory name that only shares a prefix does not match.
    actual = header_symlinks.links_for_target(links, "Sour")
    asserts.equals(env, struct(hdrs = [], srcs = []), actual)

    return unittest.end(env)

links_for_target_test = unittest.make(_links_for_target_test)

def _include_dirs_test(ctx):
    env = unittest.begin(ctx)

    links = [
        _link("B/X.h", "C/X.h"),
        _link("A/X.h", "C/X.h"),
        _link("A/Y.h", "C/Y.h"),
        _link("Top.h", "C/Top.h"),
    ]
    asserts.equals(env, ["", "A", "B"], header_symlinks.include_dirs(links))
    asserts.equals(env, "A/X.h.rspm_symlink", header_symlinks.label_name(links[1]))

    return unittest.end(env)

include_dirs_test = unittest.make(_include_dirs_test)

def _modes_test(ctx):
    env = unittest.begin(ctx)

    # The attribute definition accepts exactly these values; Bazel rejects
    # anything else when the repository rule or tag is evaluated.
    asserts.equals(env, ["warn", "ignore", "replace"], header_symlinks.mode_values)

    return unittest.end(env)

modes_test = unittest.make(_modes_test)

def _effective_mode_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        # Git and registry packages.
        struct(mode = "warn", local = False, build_file = False, exp = "warn"),
        struct(mode = "ignore", local = False, build_file = False, exp = "ignore"),
        struct(mode = "replace", local = False, build_file = False, exp = "replace"),
        # Local packages are never modified.
        struct(mode = "warn", local = True, build_file = False, exp = "warn"),
        struct(mode = "ignore", local = True, build_file = False, exp = "ignore"),
        struct(mode = "replace", local = True, build_file = False, exp = "warn"),
        # A build_file cannot recreate removed symlinks.
        struct(mode = "warn", local = False, build_file = True, exp = "warn"),
        struct(mode = "ignore", local = False, build_file = True, exp = "ignore"),
        struct(mode = "replace", local = False, build_file = True, exp = "warn"),
    ]
    for t in tests:
        actual = header_symlinks.effective_mode(
            t.mode,
            local = t.local,
            has_build_file = t.build_file,
        )
        asserts.equals(env, t.exp, actual, "{} local={} build_file={}".format(t.mode, t.local, t.build_file))

    return unittest.end(env)

effective_mode_test = unittest.make(_effective_mode_test)

def _process_ignore_test(ctx):
    env = unittest.begin(ctx)

    # "ignore" never looks at the filesystem, so it can neither change nor
    # report anything.
    def _unexpected(*_args, **_kwargs):
        fail("Expected no repository_ctx calls for \"ignore\".")

    repository_ctx = struct(
        attr = struct(bazel_package_name = "swiftpkg_foo"),
        delete = _unexpected,
        execute = _unexpected,
        file = _unexpected,
        name = "swiftpkg_foo",
        os = struct(name = "mac os x"),
        path = _unexpected,
        read = _unexpected,
    )
    for local in [False, True]:
        for has_build_file in [False, True]:
            actual = header_symlinks.process(
                repository_ctx,
                "/repo",
                "ignore",
                local = local,
                has_build_file = has_build_file,
            )
            asserts.equals(env, struct(found = [], removed = []), actual)
    header_symlinks.write_list(repository_ctx, [])

    return unittest.end(env)

process_ignore_test = unittest.make(_process_ignore_test)

def _new_fake_repository_ctx(symlinks, calls):
    """Return a fake `repository_ctx` for a package at `/repo`.

    Args:
        symlinks: A `dict` of symlink paths under `/repo` to the absolute paths
            they resolve to.
        calls: A `dict` that records the `delete` calls under `"delete"`.

    Returns:
        A `struct` that stands in for `repository_ctx`.
    """

    def _execute(args, **_kwargs):
        if args[0] == "find":
            stdout = "\n".join(["/repo/" + p for p in symlinks])
            return struct(return_code = 0, stdout = stdout, stderr = "")

        # `test -d`: no symlink here resolves to a directory.
        return struct(return_code = 1, stdout = "", stderr = "")

    def _path(p):
        rel = p.removeprefix("/repo/")
        return struct(exists = True, realpath = symlinks.get(rel, p))

    def _delete(p):
        calls["delete"].append(p)

    return struct(
        attr = struct(bazel_package_name = "swiftpkg_foo"),
        delete = _delete,
        execute = _execute,
        name = "swiftpkg_foo",
        os = struct(name = "mac os x"),
        path = _path,
    )

def _process_test(ctx):
    env = unittest.begin(ctx)

    symlinks = {
        "A/Outside.h": "/elsewhere/Outside.h",
        "A/X.h": "/repo/B/X.h",
        "A/X.m": "/repo/B/X.m",
    }
    expected = [_link("A/X.h", "B/X.h")]

    tests = [
        struct(mode = "warn", local = False, build_file = False, removed = []),
        struct(mode = "replace", local = False, build_file = False, removed = expected),
        struct(mode = "replace", local = True, build_file = False, removed = []),
        struct(mode = "warn", local = True, build_file = False, removed = []),
        struct(mode = "replace", local = False, build_file = True, removed = []),
    ]
    for t in tests:
        calls = {"delete": []}
        actual = header_symlinks.process(
            _new_fake_repository_ctx(symlinks, calls),
            "/repo",
            t.mode,
            local = t.local,
            has_build_file = t.build_file,
        )
        msg = "{} local={} build_file={}".format(t.mode, t.local, t.build_file)
        asserts.equals(env, expected, actual.found, msg)
        asserts.equals(env, t.removed, actual.removed, msg)
        asserts.equals(
            env,
            ["/repo/" + link.path for link in t.removed],
            calls["delete"],
            msg,
        )

    return unittest.end(env)

process_test = unittest.make(_process_test)

def _list_content_test(ctx):
    env = unittest.begin(ctx)

    links = [_link("A/X.h", "B/X.h"), _link("C/W.h", "D/W.h")]
    asserts.equals(env, "A/X.h -> B/X.h\nC/W.h -> D/W.h\n", header_symlinks.list_content(links))
    asserts.equals(env, "rspm_header_symlinks.txt", header_symlinks.list_file)

    return unittest.end(env)

list_content_test = unittest.make(_list_content_test)

def header_symlinks_test_suite():
    return unittest.suite(
        "header_symlinks_tests",
        modes_test,
        effective_mode_test,
        process_ignore_test,
        process_test,
        list_content_test,
        links_for_target_test,
        include_dirs_test,
        select_links_test,
        select_links_chain_test,
        select_links_deterministic_test,
        warning_test,
    )
