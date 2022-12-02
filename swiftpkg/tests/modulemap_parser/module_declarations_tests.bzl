"""Tests for `module_declarations`"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal/modulemap_parser:declarations.bzl", "declarations")
load("//swiftpkg/internal/modulemap_parser:module_declarations.bzl", "module_declarations")

def _is_a_module_test(ctx):
    env = unittest.begin(ctx)

    module = declarations.module([])
    asserts.true(env, module_declarations.is_a_module(module))

    inferred_submodule = declarations.inferred_submodule()
    asserts.true(env, module_declarations.is_a_module(inferred_submodule))

    unprocessed_submodule = declarations.unprocessed_submodule([], [])
    asserts.false(env, module_declarations.is_a_module(unprocessed_submodule))

    return unittest.end(env)

is_a_module_test = unittest.make(_is_a_module_test)

def _get_member_test(ctx):
    env = unittest.begin(ctx)

    # https://clang.llvm.org/docs/Modules.html#submodule-declaration
    # module MyLib {
    #   umbrella "MyLib"
    #   explicit module * {
    #     export *
    #   }
    # }
    root_module = declarations.module("MyLib", members = [
        declarations.umbrella_directory("MyLib"),
        declarations.inferred_submodule(explicit = True, members = [
            declarations.export(wildcard = True),
        ]),
    ])

    result, err = module_declarations.get_member(root_module, [])
    asserts.equals(env, None, result)
    asserts.equals(env, "The `path` cannot be empty.", err.msg)

    result, err = module_declarations.get_member(root_module, [0])
    asserts.equals(env, None, err)
    asserts.equals(env, result.decl_type, declarations.types.umbrella_directory)

    # Error trying to access child of non-module member
    result, err = module_declarations.get_member(root_module, [0, 0])
    asserts.equals(env, None, result)
    asserts.true(env, err.msg.startswith("Invalid path."))

    result, err = module_declarations.get_member(root_module, [1])
    asserts.equals(env, None, err)
    asserts.equals(env, result.decl_type, declarations.types.inferred_submodule)

    result, err = module_declarations.get_member(root_module, [1, 0])
    asserts.equals(env, None, err)
    asserts.equals(env, result.decl_type, declarations.types.export)

    return unittest.end(env)

get_member_test = unittest.make(_get_member_test)

def _replace_member_test(ctx):
    env = unittest.begin(ctx)

    # Test single parent

    root_module = declarations.module("MyLib", members = [
        declarations.umbrella_directory("MyLib"),
        declarations.unprocessed_submodule([], []),
    ])
    new_member = declarations.inferred_submodule(explicit = True, members = [
        declarations.export(wildcard = True),
    ])
    expected = declarations.module("MyLib", members = [
        declarations.umbrella_directory("MyLib"),
        new_member,
    ])

    actual, err = module_declarations.replace_member(root_module, [1], new_member)
    asserts.equals(env, None, err)
    asserts.equals(env, expected, actual)

    # Test multiple parent levels

    # module MyLib {
    #     explicit module A {
    #       header "A.h"
    #       export *
    #     }
    # }
    root_module = declarations.module("MyLib", members = [
        declarations.module("A", explicit = True, members = [
            declarations.single_header("A.h"),
            declarations.export(wildcard = True),
        ]),
    ])
    new_member = declarations.single_header("Z.h")
    expected = declarations.module("MyLib", members = [
        declarations.module("A", explicit = True, members = [
            new_member,
            declarations.export(wildcard = True),
        ]),
    ])

    actual, err = module_declarations.replace_member(root_module, [0, 0], new_member)
    asserts.equals(env, None, err)
    asserts.equals(env, expected, actual)

    return unittest.end(env)

replace_member_test = unittest.make(_replace_member_test)

def module_declarations_test_suite():
    return unittest.suite(
        "module_declarations_tests",
        is_a_module_test,
        get_member_test,
        replace_member_test,
    )
