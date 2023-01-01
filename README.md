# Gazelle Plugin for Swift and Swit Package Rules for Bazel

This repository contains a [Gazelle plugin] and Bazel repository rules that can be used to download,
build, and consume Swift packages with [rules_swift] rules. The rules in this repository build the
external Swift packages using [rules_swift] and native C/C++ rulesets making the Swift package
products and targets available as Bazel targets.

This repository is designed to fully replace [rules_spm] and provide a foundation for future
enhancements.

## Table of Contents


## Prerequisites

### Mac OS

Be sure to install Xcode.

### Linux

You will need to [install Swift](https://swift.org/getting-started/#installing-swift). Make sure
that running `swift --version` works properly.

Don't forget that `rules_swift` [expects the use of
`clang`](https://github.com/bazelbuild/rules_swift#3-additional-configuration-linux-only). Hence,
you will need to specify `CC=clang` before running Bazel.

Finally, specify a custom `PATH` to Bazel via `--action_env`. The custom `PATH` should have the
Swift bin directory as the first item.

```sh
swift_exec=$(which swift)
real_swift_exec=$(realpath $swift_exec)
real_swift_dir=$(dirname $real_swift_exec)
new_path="${real_swift_dir}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
cat >>local.bazelrc <<EOF
build --action_env=PATH=${new_path}
EOF
```

This approach was necessary to successfully execute the examples on an Ubuntu runner using Github
actions. See the [CI GitHub workflow] for more details.

[Gazelle]: https://github.com/bazelbuild/bazel-gazelle
[Gazelle plugin]: https://github.com/bazelbuild/bazel-gazelle/blob/master/extend.md
[rules_swift]: https://github.com/bazelbuild/rules_swift
[rules_spm]: https://github.com/cgrindel/rules_spm
[CI GitHub workflow]: .github/workflows/ci.yml
