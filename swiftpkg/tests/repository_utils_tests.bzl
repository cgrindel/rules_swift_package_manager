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

def _working_directory_variants_test(ctx):
    env = unittest.begin(ctx)

    def _repository_ctx(realpaths):
        # Stand-in for `repository_ctx`, whose `path()` returns an object
        # exposing `realpath`. `realpaths` maps a lexical path to the
        # symlink-resolved path that Bazel would report for it.
        def _path(p):
            return struct(realpath = realpaths.get(p, p))

        return struct(path = _path)

    tests = [
        struct(
            msg = "empty working directory yields no variants",
            working_directory = "",
            realpaths = {},
            expected = [],
        ),
        struct(
            msg = "unresolved path yields only itself (no duplicate)",
            working_directory = "/path/to/MyApp",
            realpaths = {},
            expected = ["/path/to/MyApp"],
        ),
        struct(
            msg = """\
symlinked path yields both spellings so SPM's resolved output matches \
(GH-2140)\
""",
            working_directory = "/path/to/link/MyApp",
            realpaths = {"/path/to/link/MyApp": "/path/to/real/MyApp"},
            expected = ["/path/to/link/MyApp", "/path/to/real/MyApp"],
        ),
        struct(
            msg = "macOS /var -> /private/var symlink yields both spellings",
            working_directory = "/var/tmp/out/repos/foo",
            realpaths = {
                "/var/tmp/out/repos/foo": "/private/var/tmp/out/repos/foo",
            },
            expected = [
                "/var/tmp/out/repos/foo",
                "/private/var/tmp/out/repos/foo",
            ],
        ),
    ]

    for test in tests:
        actual = repository_utils.working_directory_variants(
            _repository_ctx(test.realpaths),
            test.working_directory,
        )
        asserts.equals(env, test.expected, actual, test.msg)

    return unittest.end(env)

working_directory_variants_test = unittest.make(_working_directory_variants_test)

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
        relativize_repo_path_test,
        replace_working_directory_test,
        working_directory_variants_test,
    )
