"""Tests for build_declarations module"""

# load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
# load("//spm:defs.bzl", "build_declarations")

# def _load_statement_test(ctx):
#     env = unittest.begin(ctx)

#     actual = build_declarations.load_statement(
#         "@chicken//:foo.bzl",
#         "chicken",
#         "animal",
#         "chicken",
#     )
#     expected = struct(
#         location = "@chicken//:foo.bzl",
#         symbols = ["animal", "chicken"],
#     )
#     asserts.equals(env, expected, actual)

#     return unittest.end(env)

# load_statement_test = unittest.make(_load_statement_test)

# def _target_test(ctx):
#     env = unittest.begin(ctx)

#     target_type = "chicken_library"
#     name = "smidgen"
#     declaration = """
# chicken_library(
#     name = "smidgen"
# )
# """
#     actual = build_declarations.target(
#         type = target_type,
#         name = name,
#         declaration = declaration,
#     )
#     expected = struct(
#         type = target_type,
#         name = name,
#         declaration = declaration,
#     )
#     asserts.equals(env, expected, actual)

#     return unittest.end(env)

# target_test = unittest.make(_target_test)

# def _create_test(ctx):
#     env = unittest.begin(ctx)

#     actual = build_declarations.create(
#         load_statements = [
#             build_declarations.load_statement(":chicken.bzl", "chicken_library"),
#             build_declarations.load_statement(":foo.bzl", "foo_library"),
#             build_declarations.load_statement(":chicken.bzl", "chicken_library"),
#             build_declarations.load_statement(":chicken.bzl", "chicken_binary"),
#         ],
#         targets = [
#             build_declarations.target(
#                 type = "chicken_library",
#                 name = "zebra",
#                 declaration = """chicken_library(name = "zebra")""",
#             ),
#             build_declarations.target(
#                 type = "foo_library",
#                 name = "bar",
#                 declaration = """foo_library(name = "bar")""",
#             ),
#             build_declarations.target(
#                 type = "chicken_library",
#                 name = "alpha",
#                 declaration = """chicken_library(name = "alpha")""",
#             ),
#             build_declarations.target(
#                 type = "chicken_binary",
#                 name = "beta",
#                 declaration = """chicken_binary(name = "beta")""",
#             ),
#         ],
#     )
#     expected = struct(
#         load_statements = [
#             build_declarations.load_statement(":chicken.bzl", "chicken_binary", "chicken_library"),
#             build_declarations.load_statement(":foo.bzl", "foo_library"),
#         ],
#         targets = [
#             build_declarations.target(
#                 type = "chicken_binary",
#                 name = "beta",
#                 declaration = """chicken_binary(name = "beta")""",
#             ),
#             build_declarations.target(
#                 type = "chicken_library",
#                 name = "alpha",
#                 declaration = """chicken_library(name = "alpha")""",
#             ),
#             build_declarations.target(
#                 type = "chicken_library",
#                 name = "zebra",
#                 declaration = """chicken_library(name = "zebra")""",
#             ),
#             build_declarations.target(
#                 type = "foo_library",
#                 name = "bar",
#                 declaration = """foo_library(name = "bar")""",
#             ),
#         ],
#     )
#     asserts.equals(env, expected, actual)

#     return unittest.end(env)

# create_test = unittest.make(_create_test)

# def _merge_test(ctx):
#     env = unittest.begin(ctx)

#     a = build_declarations.create(
#         load_statements = [
#             build_declarations.load_statement(":chicken.bzl", "chicken_library"),
#         ],
#         targets = [
#             build_declarations.target(
#                 type = "chicken_library",
#                 name = "zebra",
#                 declaration = """chicken_library(name = "zebra")""",
#             ),
#         ],
#     )
#     b = build_declarations.create(
#         load_statements = [
#             build_declarations.load_statement(":chicken.bzl", "chicken_library"),
#         ],
#         targets = [
#             build_declarations.target(
#                 type = "chicken_library",
#                 name = "alpha",
#                 declaration = """chicken_library(name = "alpha")""",
#             ),
#         ],
#     )
#     c = build_declarations.create(
#         load_statements = [
#             build_declarations.load_statement(":foo.bzl", "foo_library"),
#         ],
#         targets = [
#             build_declarations.target(
#                 type = "foo_library",
#                 name = "bar",
#                 declaration = """foo_library(name = "bar")""",
#             ),
#         ],
#     )
#     actual = build_declarations.merge(a, b, c)
#     expected = build_declarations.create(
#         load_statements = [
#             build_declarations.load_statement(":chicken.bzl", "chicken_library"),
#             build_declarations.load_statement(":foo.bzl", "foo_library"),
#         ],
#         targets = [
#             build_declarations.target(
#                 type = "chicken_library",
#                 name = "alpha",
#                 declaration = """chicken_library(name = "alpha")""",
#             ),
#             build_declarations.target(
#                 type = "chicken_library",
#                 name = "zebra",
#                 declaration = """chicken_library(name = "zebra")""",
#             ),
#             build_declarations.target(
#                 type = "foo_library",
#                 name = "bar",
#                 declaration = """foo_library(name = "bar")""",
#             ),
#         ],
#     )
#     asserts.equals(env, expected, actual)

#     return unittest.end(env)

# merge_test = unittest.make(_merge_test)

# def _generate_build_file_content_test(ctx):
#     env = unittest.begin(ctx)

#     build_decl = build_declarations.create(
#         load_statements = [
#             build_declarations.load_statement(":chicken.bzl", "chicken_library"),
#             build_declarations.load_statement(":foo.bzl", "foo_library"),
#         ],
#         targets = [
#             build_declarations.target(
#                 type = "chicken_library",
#                 name = "alpha",
#                 declaration = """chicken_library(name = "alpha")""",
#             ),
#             build_declarations.target(
#                 type = "chicken_library",
#                 name = "zebra",
#                 declaration = """chicken_library(name = "zebra")""",
#             ),
#             build_declarations.target(
#                 type = "foo_library",
#                 name = "bar",
#                 declaration = """foo_library(name = "bar")""",
#             ),
#         ],
#     )
#     actual = build_declarations.generate_build_file_content(build_decl)
#     expected = """\
# load(":chicken.bzl", "chicken_library")
# load(":foo.bzl", "foo_library")

# chicken_library(name = "alpha")

# chicken_library(name = "zebra")

# foo_library(name = "bar")
# """
#     asserts.equals(env, expected, actual)

#     return unittest.end(env)

# generate_build_file_content_test = unittest.make(_generate_build_file_content_test)

# def _bazel_deps_str_test(ctx):
#     env = unittest.begin(ctx)

#     actual = build_declarations.bazel_deps_str(
#         pkg_name = "chicken",
#         target_deps = [
#             "target:chicken/foo",
#             "target:smidgen/bar",
#         ],
#     )
#     expected = """\
#         ":foo",
#         "//smidgen:bar",\
# """
#     asserts.equals(env, expected, actual)

#     return unittest.end(env)

# bazel_deps_str_test = unittest.make(_bazel_deps_str_test)

# def _bazel_list_str_test(ctx):
#     env = unittest.begin(ctx)

#     actual = build_declarations.bazel_list_str([])
#     expected = ""
#     asserts.equals(env, expected, actual, "no values")

#     values = ["apple", "pear", "cherries"]

#     actual = build_declarations.bazel_list_str(values, double_quote_values = False)
#     expected = """\
#         apple,
#         pear,
#         cherries,\
# """
#     asserts.equals(env, expected, actual, "values, no double quote")

#     actual = build_declarations.bazel_list_str(values)
#     expected = """\
#         "apple",
#         "pear",
#         "cherries",\
# """
#     asserts.equals(env, expected, actual, "values, double quote")

#     actual = build_declarations.bazel_list_str(values, indent = "")
#     expected = """\
# "apple",
# "pear",
# "cherries",\
# """
#     asserts.equals(env, expected, actual, "values, no double quote, no indent")

#     return unittest.end(env)

# bazel_list_str_test = unittest.make(_bazel_list_str_test)

# def build_declarations_test_suite():
#     return unittest.suite(
#         "build_declarations_tests",
#         load_statement_test,
#         target_test,
#         create_test,
#         merge_test,
#         generate_build_file_content_test,
#         bazel_deps_str_test,
#         bazel_list_str_test,
#     )
