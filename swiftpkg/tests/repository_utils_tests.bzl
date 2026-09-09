"""Tests for `repository_utils` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//swiftpkg/internal:repository_utils.bzl",
    "repository_utils",
)

def _copy_test(ctx):
    env = unittest.begin(ctx)

    file_calls = []

    def _read(src):
        return "file content from " + str(src)

    # buildifier: disable=unused-variable
    def _file(path, content = "", executable = False):
        file_calls.append(struct(
            path = path,
            content = content,
            executable = executable,
        ))

    repository_ctx = struct(read = _read, file = _file)

    repository_utils.copy(repository_ctx, "//:.netrc", ".netrc")

    asserts.equals(env, 1, len(file_calls), "one file should be written")
    asserts.equals(env, ".netrc", file_calls[0].path)
    asserts.equals(
        env,
        "file content from //:.netrc",
        file_calls[0].content,
    )
    asserts.equals(env, False, file_calls[0].executable)

    return unittest.end(env)

copy_test = unittest.make(_copy_test)

def _exec_spm_command_uses_configured_swift_test(ctx):
    env = unittest.begin(ctx)

    calls = []
    watched = []

    def _execute(args, environment = {}, working_directory = ""):
        asserts.equals(
            env,
            ["//toolchain:swift"],
            watched,
            "the executable should be watched before it is executed",
        )
        calls.append(struct(
            args = args,
            environment = environment,
            working_directory = working_directory,
        ))
        return struct(return_code = 0, stdout = "configured", stderr = "")

    def _path(label):
        asserts.equals(env, "//toolchain:swift", label)
        return "/toolchain/usr/bin/swift"

    def _watch(label):
        watched.append(label)

    repository_ctx = struct(
        execute = _execute,
        os = struct(name = "mac os x"),
        path = _path,
        watch = _watch,
    )

    actual = repository_utils.exec_spm_command(
        repository_ctx,
        ["swift", "package", "--version"],
        swift_executable = "//toolchain:swift",
    )

    asserts.equals(env, "configured", actual)
    asserts.equals(env, ["//toolchain:swift"], watched)
    asserts.equals(env, 1, len(calls))
    asserts.equals(
        env,
        ["/toolchain/usr/bin/swift", "package", "--version"],
        calls[0].args,
    )

    return unittest.end(env)

exec_spm_command_uses_configured_swift_test = unittest.make(
    _exec_spm_command_uses_configured_swift_test,
)

def _exec_spm_command_falls_back_to_path_test(ctx):
    env = unittest.begin(ctx)

    calls = []

    # buildifier: disable=unused-variable
    def _execute(args, environment = {}, working_directory = ""):
        calls.append(args)
        return struct(return_code = 0, stdout = "path", stderr = "")

    repository_ctx = struct(
        execute = _execute,
        os = struct(name = "linux"),
    )

    actual = repository_utils.exec_spm_command(
        repository_ctx,
        ["swift", "package", "--version"],
    )

    asserts.equals(env, "path", actual)
    asserts.equals(env, [["swift", "package", "--version"]], calls)

    return unittest.end(env)

exec_spm_command_falls_back_to_path_test = unittest.make(
    _exec_spm_command_falls_back_to_path_test,
)

def _exec_spm_command_falls_back_to_xcrun_test(ctx):
    env = unittest.begin(ctx)

    calls = []

    # buildifier: disable=unused-variable
    def _execute(args, environment = {}, working_directory = ""):
        calls.append(args)
        return struct(return_code = 0, stdout = "xcrun", stderr = "")

    repository_ctx = struct(
        execute = _execute,
        os = struct(name = "mac os x"),
    )

    actual = repository_utils.exec_spm_command(
        repository_ctx,
        ["swift", "package", "--version"],
    )

    asserts.equals(env, "xcrun", actual)
    asserts.equals(
        env,
        [["xcrun", "swift", "package", "--version"]],
        calls,
    )

    return unittest.end(env)

exec_spm_command_falls_back_to_xcrun_test = unittest.make(
    _exec_spm_command_falls_back_to_xcrun_test,
)

def _replace_working_directory_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "simple replacement",
            json_str = """\
{"path": "/path/to/MyApp/Sources/main.swift"}\
""",
            working_directory = "/path/to/MyApp",
            expected = """\
{"path": "./Sources/main.swift"}\
""",
        ),
        struct(
            msg = """\
prefix-safe: does not corrupt paths sharing a prefix (GH-2139)\
""",
            json_str = """\
{
  "path": "/path/to/LocalPkg/Sources/main.swift",
  "dep": "/path/to/LocalPkgUtils/Sources/lib.swift"
}\
""",
            working_directory = "/path/to/LocalPkg",
            expected = """\
{
  "path": "./Sources/main.swift",
  "dep": "/path/to/LocalPkgUtils/Sources/lib.swift"
}\
""",
        ),
        struct(
            msg = "multiple occurrences replaced",
            json_str = """\
{"src": "/work/dir/a.swift", "test": "/work/dir/b.swift"}\
""",
            working_directory = "/work/dir",
            expected = """\
{"src": "./a.swift", "test": "./b.swift"}\
""",
        ),
        struct(
            msg = "no match leaves string unchanged",
            json_str = """\
{"path": "/other/place/file.swift"}\
""",
            working_directory = "/path/to/MyApp",
            expected = """\
{"path": "/other/place/file.swift"}\
""",
        ),
        struct(
            msg = """\
empty working directory leaves string unchanged\
""",
            json_str = """\
{"path": "/path/to/MyApp/file.swift"}\
""",
            working_directory = "",
            expected = """\
{"path": "/path/to/MyApp/file.swift"}\
""",
        ),
        struct(
            msg = """\
working directory without trailing content is replaced\
""",
            json_str = """\
{"path": "/path/to/MyApp"}\
""",
            working_directory = "/path/to/MyApp",
            expected = """\
{"path": "./"}\
""",
        ),
    ]

    for test in tests:
        actual = repository_utils.replace_working_directory(
            test.json_str,
            test.working_directory,
        )
        asserts.equals(env, test.expected, actual, test.msg)

    return unittest.end(env)

replace_working_directory_test = unittest.make(_replace_working_directory_test)

def _relativize_repo_path_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "path inside the workspace root is relativized",
            path = "/path/to/MyApp/third_party/foo",
            workspace_root = "/path/to/MyApp",
            expected = "third_party/foo",
        ),
        struct(
            msg = "path in a subdirectory workspace root keeps the prefix",
            path = "/path/to/MyApp/swift/third_party/foo",
            workspace_root = "/path/to/MyApp",
            expected = "swift/third_party/foo",
        ),
        struct(
            msg = """\
prefix-safe: sibling sharing a prefix is not relativized (GH-2405)\
""",
            path = "/path/to/MyAppFrameworks/foo",
            workspace_root = "/path/to/MyApp",
            expected = "/path/to/MyAppFrameworks/foo",
        ),
        struct(
            msg = "path outside the workspace root is left absolute",
            path = "/other/place/foo",
            workspace_root = "/path/to/MyApp",
            expected = "/other/place/foo",
        ),
        struct(
            msg = "path equal to the workspace root becomes the current dir",
            path = "/path/to/MyApp",
            workspace_root = "/path/to/MyApp",
            expected = ".",
        ),
        struct(
            msg = "trailing slash on the workspace root is handled",
            path = "/path/to/MyApp/third_party/foo",
            workspace_root = "/path/to/MyApp/",
            expected = "third_party/foo",
        ),
        struct(
            msg = "empty workspace root leaves the path unchanged",
            path = "/path/to/MyApp/third_party/foo",
            workspace_root = "",
            expected = "/path/to/MyApp/third_party/foo",
        ),
    ]

    for test in tests:
        actual = repository_utils.relativize_repo_path(
            test.path,
            test.workspace_root,
        )
        asserts.equals(env, test.expected, actual, test.msg)

    return unittest.end(env)

relativize_repo_path_test = unittest.make(_relativize_repo_path_test)

def repository_utils_test_suite():
    return unittest.suite(
        "repository_utils_tests",
        copy_test,
        exec_spm_command_falls_back_to_path_test,
        exec_spm_command_falls_back_to_xcrun_test,
        exec_spm_command_uses_configured_swift_test,
        relativize_repo_path_test,
        replace_working_directory_test,
    )
