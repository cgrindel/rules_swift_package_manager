# skip_local_transitive_dependencies Example

This example has two local packages: `LocalPackageA` depends on `LocalPackageB`, which depends on a
remote package (OpenCombine). Both local packages are also direct dependencies in `Package.swift`.

In v1, this example set `resolve_transitive_local_dependencies = False` and `cached_json_directory`
on `swift_deps.from_package`. v2 has neither option. The `@swift_package//:cache` step resolves the
whole graph with SwiftPM and checks the manifests into `swift_deps/any`, so the extension reads
local packages from the slice instead of resolving them at fetch time.
