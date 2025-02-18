# skip_local_transitive_dependencies Example

This example demonstrates setting the `resolve_transitive_local_dependencies` option on 
`swift_deps.from_package` to `False` to disable resolving transitive local dependencies.

Setting `resolve_transitive_local_dependencies` to `False` does not disable resolving
transitive remote dependencies from either local or remote dependencies. It only disables
resolving transitive dependencies from a direct local package dependency to other local
packages.
