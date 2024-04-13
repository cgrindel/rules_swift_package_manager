def _new(direct_dep_repo_names = []):
    return struct(
        direct_dep_repo_names = direct_dep_repo_names,
    )

def _write(module_or_repository_ctx, swift_deps_info, path = "swift_deps_info.json"):
    module_or_repository_ctx.file(
        path,
        executable = False,
        content = json.encode_indent(
            swift_deps_info,
            indent = "  ",
        ),
    )

swift_deps_infos = struct(
    new = _new,
    write = _write,
)

def _swift_deps_info_impl(repository_ctx):
    swift_deps_info = swift_deps_infos.new(
        direct_dep_repo_names = repository_ctx.attr.direct_dep_repo_names,
    )
    swift_deps_infos.write(repository_ctx, swift_deps_info)
    repository_ctx.file(
        "BUILD.bazel",
        executable = False,
        content = """
exports_files(["swift_deps_info.json"])
""",
    )

swift_deps_info = repository_rule(
    implementation = _swift_deps_info_impl,
    attrs = {
        "direct_dep_repo_names": attr.string_list(
            mandatory = True,
            doc = """\
The repository names for the Swift direct dependencies for the Bazel workspace.\
""",
        ),
    },
    doc = """\
Stores information about the Swift dependencies for a workspace. It is used by \
other tooling (e.g., Swift Gazelle plugin).\
""",
)
