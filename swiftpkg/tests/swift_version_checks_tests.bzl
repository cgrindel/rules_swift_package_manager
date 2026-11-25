"""Tests for `swift_version_checks` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load("//swiftpkg/internal:starlark_codegen.bzl", scg = "starlark_codegen")
load("//swiftpkg/internal:swift_version_checks.bzl", "swift_version_checks")

_LABEL = ":swift_version_check"

def _attach_adds_data_to_library_kinds_test(ctx):
    env = unittest.begin(ctx)

    select_data = scg.new_fn_call("select", {"//conditions:default": [":b"]})
    decls = [
        build_decls.new("swift_library", "Foo.rspm", attrs = {"srcs": ["a.swift"]}),
        build_decls.new("cc_library", "Bar.rspm", attrs = {"data": [":x"]}),
        build_decls.new("objc_library", "Baz.rspm", attrs = {"data": select_data}),
        build_decls.new("alias", "Foo", attrs = {"actual": ":Foo.rspm"}),
        build_decls.new("swift_compiler_plugin", "Macros.rspm", attrs = {}),
        build_decls.new("apple_static_xcframework_import", "S.rspm", attrs = {}),
        build_decls.new("apple_dynamic_xcframework_import", "D.rspm", attrs = {}),
    ]

    actual = swift_version_checks.attach(decls)

    asserts.equals(env, 7, len(actual))
    asserts.equals(env, {"data": [_LABEL]}, actual[4].attrs, "swift_compiler_plugin")
    asserts.equals(env, {"data": [_LABEL]}, actual[5].attrs, "apple_static_xcframework_import")
    asserts.equals(
        env,
        decls[6],
        actual[6],
        "apple_dynamic_xcframework_import has no data attribute",
    )
    asserts.equals(
        env,
        {"data": [_LABEL], "srcs": ["a.swift"]},
        actual[0].attrs,
        "swift_library without data gets the label",
    )
    asserts.equals(
        env,
        {"data": [":x", _LABEL]},
        actual[1].attrs,
        "cc_library keeps its data and gets the label last",
    )
    asserts.equals(
        env,
        'select({\n    "//conditions:default": [":b"],\n}) + [":swift_version_check"]',
        scg.to_starlark(actual[2].attrs["data"]),
        "a select()-bearing data value gets the label concatenated",
    )
    asserts.equals(env, decls[3], actual[3], "alias is untouched")
    asserts.equals(
        env,
        {"srcs": ["a.swift"]},
        decls[0].attrs,
        "the input decls are not mutated",
    )

    again = swift_version_checks.attach(actual)
    asserts.equals(env, [_LABEL], again[0].attrs["data"], "idempotent: plain list")
    asserts.equals(env, [":x", _LABEL], again[1].attrs["data"], "idempotent: existing list")
    asserts.equals(
        env,
        scg.to_starlark(actual[2].attrs["data"]),
        scg.to_starlark(again[2].attrs["data"]),
        "idempotent: select()",
    )

    return unittest.end(env)

attach_adds_data_to_library_kinds_test = unittest.make(
    _attach_adds_data_to_library_kinds_test,
)

def _decl_test(ctx):
    env = unittest.begin(ctx)

    actual = swift_version_checks.decl("swift/macos")

    asserts.equals(env, "swift_version_check", actual.kind)
    asserts.equals(env, "swift_version_check", actual.name)
    asserts.equals(
        env,
        {"slice_dir": "swift/macos", "version_file": "swift_version.txt"},
        actual.attrs,
    )

    return unittest.end(env)

decl_test = unittest.make(_decl_test)

def swift_version_checks_test_suite():
    return unittest.suite(
        "swift_version_checks_tests",
        attach_adds_data_to_library_kinds_test,
        decl_test,
    )
