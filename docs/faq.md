# Frequently Asked Questions (FAQ)

## Table of Contents

<!-- MARKDOWN TOC: BEGIN -->
* [Does this replace [rules_spm]?](#does-this-replace-rules_spm)
* [Where is the Swift gazelle plugin?](#where-is-the-swift-gazelle-plugin)
* [After running `//:swift_update_pkgs`, I see a `.build` directory. What is it? Do I need it?](#after-running-swift_update_pkgs-i-see-a-build-directory-what-is-it-do-i-need-it)
* [Can I store the Swift dependency files in a sub-package (i.e., not in the root of the workspace)?](#can-i-store-the-swift-dependency-files-in-a-sub-package-ie-not-in-the-root-of-the-workspace)
* [How do I handle the error `Unable to resolve byName reference XXX in @swiftpkg_yyy.`?](#how-do-i-handle-the-error-unable-to-resolve-byname-reference-xxx-in-swiftpkg_yyy)
  * [How do I fix this issue?](#how-do-i-fix-this-issue)
  * [What is the cause of the error? Why can't `rules_swift_package_manager` handle this situation?](#what-is-the-cause-of-the-error-why-cant-rules_swift_package_manager-handle-this-situation)
  <!-- MARKDOWN TOC: END -->

## Does this replace [rules_spm]?

Yes. There are some [limitations with the rules_spm
implementation](https://github.com/cgrindel/rules_spm/discussions/157). After receiving feedback and
suggestions from the community, we opted to create a clean sheet implementation which includes new
features and improvements:

- Bazel build file generation for the primary workspace.
- Build the external dependencies with [rules_swift].
- Pin the exact versions for the direct and transitive dependencies.

## Where is the Swift gazelle plugin?

It has moved to https://github.com/cgrindel/swift_gazelle_plugin.

## After running `//:swift_update_pkgs`, I see a `.build` directory. What is it? Do I need it?

The `//:swift_update_pkgs` target runs the Gazelle plugin in `update-repos` mode. This mode
resolves the external dependencies listed in your `Package.swift` by running Swift package manager
commands. These commands result in a `.build` directory being created. The directory is a side
effect of running the Swift package manager commands. It can be ignored and should not be checked
into source control. It is not used by the Gazelle plugin or the Starlark repository rules.

## Can I store the Swift dependency files in a sub-package (i.e., not in the root of the workspace)?

Yes. The [vapor example] demonstrates storing the Swift dependency files in a sub-package called
`swift`.

## How do I handle the error `Unable to resolve byName reference XXX in @swiftpkg_yyy.`?

tl;dr A transitive dependency uses a by-name product reference format that was deprecated in Swift
5.2. You need to patch the Swift package to use a more explicit product reference.

### How do I fix this issue?

[Patch the Swift package] to use a fully-qualified product reference.

Let's look at an example. At the time of this writing, the [pusher-websocket-swift Package.swift]
refers to the `TweetNacl` product in the `tweetnacl-swiftwrap` package using just the name of the
product.

```swift
// Parts of the definition have been omitted for brevity.
let package = Package(
    name: "PusherSwift",
    dependencies: [
        .package(url: "https://github.com/pusher/NWWebSocket.git", .upToNextMajor(from: "0.5.4")),
        .package(url: "https://github.com/bitmark-inc/tweetnacl-swiftwrap", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "PusherSwift",
            dependencies: [
                "NWWebSocket",
                "TweetNacl",   // <=== byName reference to product in tweetnacl-swiftwrap
            ],
            path: "Sources"
        ),
    ],
)
```

To make this work with `rules_swift_package_manager`, you need to [patch this file] so that the
reference is the following:

```swift
        .target(
            name: "PusherSwift",
            dependencies: [
                "NWWebSocket",
                .product(name: "TweetNacl", package: "tweetnacl-swiftwrap"),  // <=== Explicit ref
            ],
            path: "Sources"
        ),
```

### What is the cause of the error? Why can't `rules_swift_package_manager` handle this situation?

This specific case is the reason that previous versions of `rules_swift_package_manager`
pre-processed the transitive Swift dependencies using the Gazelle plugin’s `update-repos` action and
stored the results in a JSON file that was checked into source control.

Here is a quick explainer of why `rules_swift_package_manager` cannot resolve this dependency with
the new architecture:

- Each Swift package is declared as an external Bazel repository.
- During the loading phase, there is no mechanism for one external repository to peek into another
  external repository. In other words, a Swift package cannot query another Swift package to
  determine all of the available products.
- So, when `rules_swift_package_manager` generates a `BUILD.bazel` file for a Swift package external
  repo, it only has the information that is returned by calling `swift package description` and
  `swift package dump-package`. The output from these calls only provides the identity and the type
  of the Swift package (e.g., remote, file system).
- As a result, `byName` lookups can only be resolved to the targets/products in the current package
  and to products in Swift packages where the identity exactly matches the product name.

[Patch the Swift package]: /docs/patch_swift_package.md
[patch this file]: /docs/patch_swift_package.md
[pusher-websocket-swift Package.swift]: https://github.com/pusher/pusher-websocket-swift/blob/886341f9dad453c9822f2525136ee2006a6c3c9e/Package.swift
[rules_swift]: https://github.com/bazelbuild/rules_swift
[vapor example]: /examples/vapor_example
