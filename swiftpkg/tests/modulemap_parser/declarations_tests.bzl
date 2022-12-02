"""Tests for declarations module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//swiftpkg/internal/modulemap_parser:declarations.bzl",
    "declarations",
    dts = "declaration_types",
)

def _module_test(ctx):
    env = unittest.begin(ctx)

    expected = struct(
        decl_type = dts.module,
        module_id = "MyModule",
        explicit = True,
        framework = False,
        attributes = ["system", "extern_c"],
        members = ["foo"],
    )
    result = declarations.module(
        module_id = "MyModule",
        explicit = True,
        framework = False,
        attributes = ["system", "extern_c"],
        members = ["foo"],
    )
    asserts.equals(env, expected, result)

    return unittest.end(env)

module_test = unittest.make(_module_test)

def _extern_module_test(ctx):
    env = unittest.begin(ctx)

    expected = struct(
        decl_type = dts.extern_module,
        module_id = "MyModule",
        definition_path = "path/to/definition",
    )
    result = declarations.extern_module(
        module_id = "MyModule",
        definition_path = "path/to/definition",
    )
    asserts.equals(env, expected, result)

    return unittest.end(env)

extern_module_test = unittest.make(_extern_module_test)

def _single_header_test(ctx):
    env = unittest.begin(ctx)

    expected = struct(
        decl_type = dts.single_header,
        path = "path/to/header.h",
        private = False,
        textual = True,
        attribs = None,
    )
    actual = declarations.single_header(
        path = "path/to/header.h",
        private = False,
        textual = True,
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

single_header_test = unittest.make(_single_header_test)

def _umbrella_header_test(ctx):
    env = unittest.begin(ctx)

    expected = struct(
        decl_type = dts.umbrella_header,
        path = "path/to/header.h",
        attribs = None,
    )
    actual = declarations.umbrella_header(
        path = "path/to/header.h",
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

umbrella_header_test = unittest.make(_umbrella_header_test)

def _exclude_header_test(ctx):
    env = unittest.begin(ctx)

    expected = struct(
        decl_type = dts.exclude_header,
        path = "path/to/header.h",
        attribs = None,
    )
    actual = declarations.exclude_header(
        path = "path/to/header.h",
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

exclude_header_test = unittest.make(_exclude_header_test)

def _umbrella_directory_test(ctx):
    env = unittest.begin(ctx)

    expected = struct(
        decl_type = dts.umbrella_directory,
        path = "path/to/headers",
    )
    actual = declarations.umbrella_directory(
        path = "path/to/headers",
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

umbrella_directory_test = unittest.make(_umbrella_directory_test)

def _export_test(ctx):
    env = unittest.begin(ctx)

    expected = struct(
        decl_type = dts.export,
        identifiers = ["foo"],
        wildcard = True,
    )
    actual = declarations.export(
        identifiers = ["foo"],
        wildcard = True,
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

export_test = unittest.make(_export_test)

def _link_test(ctx):
    env = unittest.begin(ctx)

    expected = struct(
        decl_type = dts.link,
        name = "sqlite3",
        framework = False,
    )
    actual = declarations.link("sqlite3")
    asserts.equals(env, expected, actual)

    expected = struct(
        decl_type = dts.link,
        name = "sqlite3",
        framework = True,
    )
    actual = declarations.link("sqlite3", framework = True)
    asserts.equals(env, expected, actual)

    return unittest.end(env)

link_test = unittest.make(_link_test)

def _copy_module_test(ctx):
    env = unittest.begin(ctx)

    # Test module

    module = declarations.module(
        "MyLib",
        explicit = True,
        framework = True,
        members = [declarations.single_header("A.h")],
    )
    new_members = [declarations.single_header("Z.h")]
    expected = declarations.module(
        "MyLib",
        explicit = True,
        framework = True,
        members = new_members,
    )

    actual, err = declarations.copy_module(module, members = new_members)
    asserts.equals(env, None, err)
    asserts.equals(env, expected, actual)

    # Test inferred submodule

    inferred_submodule = declarations.inferred_submodule(
        explicit = True,
        framework = True,
        members = [declarations.single_header("A.h")],
    )
    new_members = [declarations.single_header("Z.h")]
    expected = declarations.inferred_submodule(
        explicit = True,
        framework = True,
        members = new_members,
    )

    actual, err = declarations.copy_module(inferred_submodule, members = new_members)
    asserts.equals(env, None, err)
    asserts.equals(env, expected, actual)

    return unittest.end(env)

copy_module_test = unittest.make(_copy_module_test)

def declarations_test_suite():
    return unittest.suite(
        "declarations_tests",
        module_test,
        extern_module_test,
        single_header_test,
        umbrella_header_test,
        exclude_header_test,
        umbrella_directory_test,
        export_test,
        link_test,
        copy_module_test,
    )
