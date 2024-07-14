# Frequently Asked Questions (FAQ)

## Table of Contents

<!-- MARKDOWN TOC: BEGIN -->

- [Why use Gazelle and Go?](#why-use-gazelle-and-go)
- [Why split the implementation between Go and Starlark?](#why-split-the-implementation-between-go-and-starlark)
  - [How does the Gazelle plugin for Go handle this?](#how-does-the-gazelle-plugin-for-go-handle-this)
- [Is the same build file generation logic used for the Go/Gazelle and Starlark implementations?](#is-the-same-build-file-generation-logic-used-for-the-gogazelle-and-starlark-implementations)
- [Does this replace rules_spm?](#does-this-replace-rules_spm)
- [Can I migrate from rules_spm to `rules_swift_package_manager`?](#can-i-migrate-from-rules_spm-to-rules_swift_package_manager)
- [Can I just manage my external Swift packages and not generate Bazel build files for my project?](#can-i-just-manage-my-external-swift-packages-and-not-generate-bazel-build-files-for-my-project)
- [After running `//:swift_update_pkgs`, I see a `.build` directory. What is it? Do I need it?](#after-running-swift_update_pkgs-i-see-a-build-directory-what-is-it-do-i-need-it)
- [Does the Gazelle plugin run Swift package manager with every execution?](#does-the-gazelle-plugin-run-swift-package-manager-with-every-execution)
- [Can I store the Swift dependency files in a sub-package (i.e., not in the root of the workspace)?](#can-i-store-the-swift-dependency-files-in-a-sub-package-ie-not-in-the-root-of-the-workspace)
- [My project builds successfully with `bazel build ...`, but it does not build when using `rules_xcodeproj`. How can I fix this?](#my-project-builds-successfully-with-bazel-build--but-it-does-not-build-when-using-rules_xcodeproj-how-can-i-fix-this)
  - [Why does this happen?](#why-does-this-happen)
- [How do I handle the error `Unable to resolve byName reference XXX in @swiftpkg_yyy.`?](#how-do-i-handle-the-error-unable-to-resolve-byname-reference-xxx-in-swiftpkg_yyy)
  - [How do I fix this issue?](#how-do-i-fix-this-issue)
  - [What is the cause of the error? Why can't `rules_swift_package_manager` handle this situation?](#what-is-the-cause-of-the-error-why-cant-rules_swift_package_manager-handle-this-situation)
  <!-- MARKDOWN TOC: END -->

## Why use Gazelle and Go?

The [Gazelle framework] provides lots of great features for generating Bazel build and Starlark
files. Right now, the best way to leverage the framework is to write the plugin in Go.

In addition, adoption of the Gazelle ecosystem has started to take off. There are [lots of useful
plugins for other languages](https://github.com/bazelbuild/bazel-gazelle#supported-languages).
Letting Gazelle generate and maintain Bazel build files is a real game changer for developer
productivity.

## Why split the implementation between Go and Starlark?

As mentioned previously, the easiest way to implement a Gazelle plugin is to write it in Go. This
works great for generating build files in the primary workspace. However, there is a chicken-and-egg
problem when it comes time to generate build files in a repository rule. The repository rule needs
to generate files during the [loading phase]. The Go toolchain and the Gazelle framework defined in
the workspace are not available to the repository rule during this phase. So, one needs to either
perform some gymnastics to build the Gazelle plugin (see below) or use a language/runtime that is
guaranteed to be available during the loading phase. Since Starlark is available during the loading
phase, the build file generation logic for the repository rules is implemented in Starlark.

### How does the Gazelle plugin for Go handle this?

In short, they assume that if you are using the Gazelle plugin for Go, then you must have a Go
toolchain installed on the host system. In essence, they shell out and run Go from the system.

## Is the same build file generation logic used for the Go/Gazelle and Starlark implementations?

No. The Gazelle plugin inspects the Swift source files and the directory structure to determine the
placement and content of the Bazel build files. The repository rules leverage information about the
Swift packages (e.g., dump and describe JSON). However, both implementations use the
`module_index.json` to resolve module references to Bazel targets for the external dependencies.

## Does this replace [rules_spm]?

Yes. There are some [limitations with the rules_spm
implementation](https://github.com/cgrindel/rules_spm/discussions/157). After receiving feedback and
suggestions from the community, we opted to create a clean sheet implementation which includes new
features and improvements:

- Bazel build file generation for the primary workspace.
- Build the external dependencies with [rules_swift].
- Pin the exact versions for the direct and transitive dependencies.

## Can I migrate from [rules_spm] to `rules_swift_package_manager`?

Absolutely. A [migration guide from rules_spm](https://github.com/cgrindel/rules_swift_package_manager/issues/99) is
on the roadmap.

## Can I just manage my external Swift packages and not generate Bazel build files for my project?

Yes. Just omit the `//:update_build_files` target that is mentioned in the [quickstart].

## After running `//:swift_update_pkgs`, I see a `.build` directory. What is it? Do I need it?

The `//:swift_update_pkgs` target runs the Gazelle plugin in `update-repos` mode. This mode
resolves the external dependencies listed in your `Package.swift` by running Swift package manager
commands. These commands result in a `.build` directory being created. The directory is a side
effect of running the Swift package manager commands. It can be ignored and should not be checked
into source control. It is not used by the Gazelle plugin or the Starlark repository rules.

## Does the Gazelle plugin run Swift package manager with every execution?

No. The Gazelle plugin only executes the Swift package manager when run in `update-repos` mode. This
mode only needs to be run when modifying your external dependencies (e.g., add/remove a dependency,
update the version selection for a dependency). The `update` mode for the Gazelle plugin generates
Bazel build files for your project. It uses information written to the `swift_deps_index.json` and
the source files that exist in your project to generate the Bazel build files.

## Can I store the Swift dependency files in a sub-package (i.e., not in the root of the workspace)?

Yes. The [vapor example] demonstrates storing the Swift dependency files in a sub-package called
`swift`.

## My project builds successfully with `bazel build ...`, but it does not build when using `rules_xcodeproj`. How can I fix this?

tl;dr Add the following to your `.bazelrc`.

```
# Ensure that sandboxed is added to the spawn strategy list when building with
# rules_xcodeproj.
build:rules_xcodeproj --spawn_strategy=remote,worker,sandboxed,local
```

Alternatively, you can use the [--strategy_regexp] flag to target the relevant targets. For
instance, if `Sources/BranchSDK/BNCContentDiscoveryManager.m` is not building properly, you can
specify `--strategy_regexp="Compiling Sources/BranchSDK/.*=sandboxed"` to use the `sandboxed` strategy
for that file. The regular expression matches on the _description_ for the action.

### Why does this happen?

This can happen with some Swift packages (e.g. `firebase-ios-sdk`). [rules_xcodeproj removes the
`sandboxed` spawn
strategy](https://github.com/MobileNativeFoundation/rules_xcodeproj/blob/6c186331c82f3cbc82e2e7fdfacb4873e409e094/xcodeproj/internal/templates/xcodeproj.bazelrc#L66-L68)
in their default build configuration due to slow performance of the MacOS sandbox. The above bazelrc
stanza adds it back. [An issue](https://github.com/cgrindel/rules_swift_package_manager/issues/712)
exists tracking the work to allow these Swift packages to be built using the `local` spawn strategy.

## How do I handle the error `Unable to resolve byName reference XXX in @swiftpkg_yyy.`?

tl;dr A transitive dependency uses a by-name product reference format that was deprecated in Swift
5.2. You need to patch the Swift package to use a more explicit product reference.

### How do I fix this issue?

[Patch the Swift package] to use a fully-qualified product reference.

Let's look at an example. At the time of this writing, the [pusher-websocket-swift Package.swift]
refers to the `TweetNacl` product in the `tweetnacl-swiftwrap` package using just the name of the
product.

```swift
// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "PusherSwift",
    platforms: [.iOS("13.0"), .macOS("10.15"), .tvOS("13.0")],
    products: [
        .library(name: "PusherSwift", targets: ["PusherSwift"])
    ],
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
        .testTarget(
            name: "PusherSwiftTests",
            dependencies: ["PusherSwift"],
            path: "Tests"
        )
    ],
    swiftLanguageVersions: [.v5]
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
- During the loading phase, there is no mechanism for one external repository to peak into another
  external repository. In other words, a Swift package cannot query another Swift package to
  determine all of the available products.
- So, when `rules_swift_package_manager` generates a `BUILD.bazel` file for a Swift package external
  repo, it only has the information that is returned by calling `swift package description` and
  `swift package dump-package`. The output from these calls only provides the identity and the type
  of the Swift package (e.g., remote, file system).
- As a result, `byName` lookups can only be resolved to the targets/products in the current package
  and to products in Swift packages where the identity exactly matches the product name.

[--strategy_regexp]: https://bazel.build/reference/command-line-reference#flag--strategy_regexp
[Gazelle framework]: https://github.com/bazelbuild/bazel-gazelle/blob/master/extend.md
[Patch the Swift package]: /docs/patch_swift_package.md
[loading phase]: https://bazel.build/run/build#loading
[patch this file]: /docs/patch_swift_package.md
[pusher-websocket-swift Package.swift]: https://github.com/pusher/pusher-websocket-swift/blob/886341f9dad453c9822f2525136ee2006a6c3c9e/Package.swift
[quickstart]: https://github.com/cgrindel/rules_swift_package_manager/blob/main/README.md#quickstart
[rules_spm]: https://github.com/cgrindel/rules_spm/
[rules_swift]: https://github.com/bazelbuild/rules_swift
[vapor example]: /examples/vapor_example
