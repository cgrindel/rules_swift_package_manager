"""Tests for `artifact_infos` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:artifact_infos.bzl", "artifact_infos", "link_types")
load(":testutils.bzl", "testutils")

def _link_type_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "current ar archive",
            file_type = """\
path/to/framework/binary/FooBar (for architecture x86_64):	current ar archive
path/to/framework/binary/FooBar (for architecture arm64):	current ar archive
""",
            load_commands = None,
            exp = link_types.static,
        ),
        struct(
            msg = "current ar archive random library",
            file_type = """\
Mach-O universal binary with 2 architectures: [x86_64:current ar archive random library] [arm64:current ar archive random library]
path/to/framework/binary/FooBar (for architecture x86_64):	current ar archive random library
path/to/framework/binary/FooBar (for architecture arm64):	current ar archive random library
""",
            load_commands = None,
            exp = link_types.static,
        ),
        struct(
            msg = "macho-o static library",
            file_type = "Mach-O 64-bit object arm64",
            load_commands = """\
Load command 1
     cmd LC_SYMTAB
Load command 2
      cmd LC_BUILD_VERSION
Load command 3
      cmd LC_DATA_IN_CODE
Load command 4
      cmd LC_LINKER_OPTIMIZATION_HINT
""",
            exp = link_types.static,
        ),
        struct(
            msg = "mach-o static universal library",
            file_type = """\
Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit object x86_64] [arm64]
path/to/framework/binary/FooBar (for architecture x86_64):	Mach-O 64-bit object x86_64
path/to/framework/binary/FooBar (for architecture arm64):	Mach-O 64-bit object arm64
""",
            load_commands = """\
Load command 0
      cmd LC_SEGMENT_64
Load command 1
     cmd LC_SYMTAB
Load command 2
      cmd LC_BUILD_VERSION
Load command 3
      cmd LC_DATA_IN_CODE
""",
            exp = link_types.static,
        ),
        struct(
            msg = "mach-o dynamic library",
            file_type = "Mach-O 64-bit object arm64",
            load_commands = """\
Load command 0
      cmd LC_SEGMENT_64
Load command 1
      cmd LC_SEGMENT_64
Load command 2
      cmd LC_SEGMENT_64
Load command 3
      cmd LC_ID_DYLIB
""",
            exp = link_types.dynamic,
        ),
        struct(
            msg = "mach-o universal dynamic library",
            file_type = """\
Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit object x86_64] [arm64]
path/to/framework/binary/FooBar (for architecture x86_64):	Mach-O 64-bit object x86_64
path/to/framework/binary/FooBar (for architecture arm64):	Mach-O 64-bit object arm64
""",
            load_commands = """\
Load command 0
      cmd LC_SEGMENT_64
Load command 1
      cmd LC_SEGMENT_64
Load command 2
      cmd LC_SEGMENT_64
Load command 3
      cmd LC_ID_DYLIB
""",
            exp = link_types.dynamic,
        ),
    ]
    for t in tests:
        path = "path/to/framework/binary/FooBar"
        stub_repository_ctx = testutils.new_stub_repository_ctx(
            repo_name = "chicken",
            file_type_results = {path: t.file_type},
            load_commands_results = {path: t.load_commands},
        )
        actual = artifact_infos.link_type(stub_repository_ctx, "path/to/framework/binary/FooBar")
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

link_type_test = unittest.make(_link_type_test)

def artifact_infos_test_suite(name = "artifact_infos_tests"):
    return unittest.suite(
        name,
        link_type_test,
    )
