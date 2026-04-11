"""Implementation for `swift_deps_info` repository rule."""

load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load("//swiftpkg/internal:build_files.bzl", "build_files")
load("//swiftpkg/internal:load_statements.bzl", "load_statements")

def _swift_deps_info_impl(repository_ctx):
    bld_file = build_files.new(
        load_stmts = [
            load_statements.new(
                "@rules_swift_package_manager//swiftpkg:defs.bzl",
                "swift_deps_index",
            ),
        ],
        decls = [
            build_decls.new(
                "swift_deps_index",
                name = "swift_deps_index",
                attrs = {
                    "direct_dep_pkg_infos": repository_ctx.attr.direct_dep_pkg_infos,
                    "visibility": ["//visibility:public"],
                },
            ),
        ],
    )
    build_files.write(repository_ctx, bld_file, "")

swift_deps_info = repository_rule(
    implementation = _swift_deps_info_impl,
    attrs = {
        # This must be a string_dict  for the labels to be written properly
        # when called from bzlmod/swift_deps.
        "direct_dep_pkg_infos": attr.string_dict(
            doc = """\
A `dict` where the key is the label for a Swift package's `pkg_info.json` file \
and the value is the Swift package's identity value.\
""",
        ),
    },
    doc = """\
Defines a repository that contains information about the Swift dependencies \
for a workspace.  It is used by other tooling (e.g., Swift Gazelle plugin).\
""",
)
