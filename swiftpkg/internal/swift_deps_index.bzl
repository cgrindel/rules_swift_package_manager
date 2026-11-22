"""The `swift_deps_index` rule has moved to swift_gazelle_plugin."""

def swift_deps_index(name, **kwargs):  # buildifier: disable=unused-variable
    """Moved to swift_gazelle_plugin.

    Load `swift_deps_index` from
    `@swift_gazelle_plugin//swift_deps_index:defs.bzl` and point it at the
    `swift_deps_info` repository:

    ```starlark
    swift_deps_index(
        name = "swift_deps_index",
        swift_deps_info = "@swift_deps_info",
    )
    ```

    Args:
        name: A unique name for this target.
        **kwargs: Ignored.
    """
    fail("swift_deps_index ({}) has moved to swift_gazelle_plugin: load it from \
@swift_gazelle_plugin//swift_deps_index:defs.bzl and set \
swift_deps_info = \"@swift_deps_info\".".format(name))
