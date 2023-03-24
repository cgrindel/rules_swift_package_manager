"""Defines the `swift_update_packages` macro."""

load("@bazel_gazelle//:def.bzl", _gazelle = "gazelle")

def swift_update_packages(
        name,
        gazelle,
        package_manifest = "Package.swift",
        swift_deps = "swift_deps.bzl",
        swift_deps_fn = "swift_dependencies",
        swift_deps_index = "swift_deps_index.json",
        update_bzlmod_use_repo_names = False,
        print_bzlmod_stanzas = False,
        update_bzlmod_stanzas = False,
        bazel_module = "MODULE.bazel",
        generate_swift_deps_for_workspace = True,
        **kwargs):
    """Defines gazelle update-repos targets that are used to resolve and update \
    Swift package dependencies.

    Args:
        name: The name of the `resolve` target as a `string`. The target name
            for the `update` target is derived from this value by appending
            `_to_latest`.
        gazelle: The label to `gazelle_binary` that includes the `swift_bazel`
            Gazelle extension.
        package_manifest: Optional. The name of the Swift package manifest file
            as a `string`.
        swift_deps: Optional. The name of the Starlark file that should be
            updated with the Swift package dependencies as a `string`.
        swift_deps_fn: Optional. The name of the Starlark function in the
            `swift_deps` file that should be updated with the Swift package
            dependencies as a `string`.
        swift_deps_index: Optional. The relative path to the Swift
            dependencies index JSON file. This path is relative to the
            repository root, not the location of this declaration.
        update_bzlmod_use_repo_names: Optional. Determines whether the Gazelle
            extension updates the use_repo names to MODULE.bazel.
        print_bzlmod_stanzas: Optional. Determines whether the Gazelle
            extension prints out bzlmod Starlark code that can be pasted into
            your `MODULE.bazel`.
        update_bzlmod_stanzas: Optional. Determines whether the Gazelle
            extension adds/updates the bzlmod Starlark code to MODULE.bazel.
        bazel_module: Optional. The relative path to the `MODULE.bazel` file.
        generate_swift_deps_for_workspace: Optional. Determines whether to
            generate the swift dependencies for clients using legacy/WORKSPACE
            loaded dependencies.
        **kwargs: Attributes that are passed along to the gazelle declarations.
    """
    _swift_update_repos_args = [
        "-from_file={}".format(package_manifest),
        "-prune",
        "-swift_dependency_index={}".format(swift_deps_index),
        "-bazel_module={}".format(bazel_module),
    ]
    if generate_swift_deps_for_workspace:
        _swift_update_repos_args.extend([
            "-generate_swift_deps_for_workspace",
            "-to_macro={swift_deps}%{swift_deps_fn}".format(
                swift_deps = swift_deps,
                swift_deps_fn = swift_deps_fn,
            ),
        ])
    if update_bzlmod_use_repo_names:
        _swift_update_repos_args.append("-update_bzlmod_use_repo_names")
    if print_bzlmod_stanzas:
        _swift_update_repos_args.append("-print_bzlmod_stanzas")
    if update_bzlmod_stanzas:
        _swift_update_repos_args.append("-update_bzlmod_stanzas")

    _gazelle(
        name = name,
        args = _swift_update_repos_args,
        command = "update-repos",
        gazelle = gazelle,
        **kwargs
    )

    _gazelle(
        name = name + "_to_latest",
        args = _swift_update_repos_args + [
            "-swift_update_packages_to_latest",
        ],
        command = "update-repos",
        gazelle = gazelle,
        **kwargs
    )
