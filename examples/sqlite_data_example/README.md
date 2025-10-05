# sqlite_data_example Example

This example demonstrates that the [sqlite-data](https://github.com/pointfreeco/sqlite-data) package
works with rules_swift_package_manager. There are many other interesting packages that are
transitively included in this example, such as [GRDB.swift](https://github.com/groue/GRDB.swift) and
a dozen libraries from the pointfreeco organization.

Two notable features that are exercised by this example are system libraries in SwiftPM package
manifests and Swift macros.

Run with `bazel run //:sqlite_data_example`:

```console
$ bazel run //:sqlite_data_example
INFO: Analyzed target //:sqlite_data_example (2 packages loaded, 108 targets configured).
INFO: Found 1 target...
Target //:sqlite_data_example up-to-date:
  bazel-bin/sqlite_data_example
INFO: Elapsed time: 0.762s, Critical Path: 0.01s
INFO: 1 process: 131 action cache hit, 1 internal.
INFO: Build completed successfully, 1 total action
INFO: Running command line: bazel-bin/sqlite_data_example
1 Frodo Baggins
3 Samwise Gamgee
```
