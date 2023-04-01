# Frequently Asked Questions (FAQ)

## Table of Contents

<!-- MARKDOWN TOC: BEGIN -->
* [Why use Gazelle and Go?](#why-use-gazelle-and-go)
* [Why split the implementation between Go and Starlark?](#why-split-the-implementation-between-go-and-starlark)
  * [How does the Gazelle plugin for Go handle this?](#how-does-the-gazelle-plugin-for-go-handle-this)
* [Is the same build file generation logic used for the Go/Gazelle and Starlark implementations?](#is-the-same-build-file-generation-logic-used-for-the-gogazelle-and-starlark-implementations)
* [Does this replace <a href="https://github\.com/cgrindel/rules\_spm/">rules\_spm</a>?](#does-this-replace-rules_spm)
* [Can I migrate from <a href="https://github\.com/cgrindel/rules\_spm/">rules\_spm</a> to rules\_swift\_package\_manager?](#can-i-migrate-from-rules_spm-to-rules_swift_package_manager)
* [Can I just manage my external Swift packages and not generate Bazel build files for my project?](#can-i-just-manage-my-external-swift-packages-and-not-generate-bazel-build-files-for-my-project)
* [After running //:swift\_update\_pkgs, I see a \.build directory\. What is it? Do I need it?](#after-running-swift_update_pkgs-i-see-a-build-directory-what-is-it-do-i-need-it)
* [Does the Gazelle plugin run Swift package manager with every execution?](#does-the-gazelle-plugin-run-swift-package-manager-with-every-execution)
* [Can I store the Swift dependency files in a sub\-package (i\.e\., not in the root of the workspace)?](#can-i-store-the-swift-dependency-files-in-a-sub-package-ie-not-in-the-root-of-the-workspace)
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
guaranteed to be available during the loading phase.  Since Starlark is available during the loading
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
commands.  These commands result in a `.build` directory being created. The directory is a side
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


[loading phase]: https://bazel.build/run/build#loading 
[quickstart]: https://github.com/cgrindel/rules_swift_package_manager/blob/main/README.md#quickstart
[rules_spm]: https://github.com/cgrindel/rules_spm/
[rules_swift]: https://github.com/bazelbuild/rules_swift
[Gazelle framework]: https://github.com/bazelbuild/bazel-gazelle/blob/master/extend.md
[vapor example]: /examples/vapor_example
