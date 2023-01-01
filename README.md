# Gazelle Plugin for Swift and Swit Package Rules for Bazel

This repository contains a [Gazelle plugin] and Bazel repository rules that can be used to download,
build, and consume Swift packages with [rules_swift] rules. The rules in this repository build the
external Swift packages using [rules_swift] and native C/C++ rulesets making the Swift package
products and targets available as Bazel targets.

This repository is designed to fully replace [rules_spm] and provide a foundation for future
enhancements.


[gazelle]: https://github.com/bazelbuild/bazel-gazelle
[Gazelle plugin]: https://github.com/bazelbuild/bazel-gazelle/blob/master/extend.md
[rules_swift]: https://github.com/bazelbuild/rules_swift
[rules_spm]: https://github.com/cgrindel/rules_spm
