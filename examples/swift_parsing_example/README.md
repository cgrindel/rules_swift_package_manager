# swift_parsing_example Example

This example demonstrates that the [swift-parsing](https://github.com/pointfreeco/swift-parsing)
package works with rules_swift_package_manager, including when its dependencies declare a higher
minimum OS than it does.

Under Swift 6.4 (Xcode 27), swift-parsing 0.15.2 resolves swift-case-paths 1.10.0, whose
`swift-tools-version: 6.4` manifest declares iOS 15 / macOS 12 while swift-parsing still declares
iOS 13 / macOS 10.15. Like `swift build`, rules_swift_package_manager raises swift-parsing's
effective deployment target to satisfy swift-case-paths instead of rejecting the import.

Older toolchains select swift-case-paths' Swift 6.0 manifest (iOS 13), so the local packages
`LocalLow` (macOS 10.15 / iOS 13) and `LocalHigh` (macOS 13 / iOS 16) reproduce the same shape
independently of the toolchain. `do_test` asserts that `LocalLow`'s generated wrapper is raised to
macOS 13 / iOS 16. `Package.resolved` carries pins for both toolchains' selections
(`xctest-dynamic-overlay` for Swift 6.0 manifests, `swift-issue-reporting` for Swift 6.4).

Run with `bazel run //:swift_parsing_example`:

```console
$ bazel run //:swift_parsing_example
user=frodo host=shire.example
LocalLow floor raised from macOS 10.15 / iOS 13 to macOS 13 / iOS 16
```
