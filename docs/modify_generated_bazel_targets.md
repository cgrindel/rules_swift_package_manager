# How to Modify Attributes on Generated Bazel Targets

## Table of Contents

<!-- MARKDOWN TOC: BEGIN -->
* [What this is](#what-this-is)
* [Find the target to modify](#find-the-target-to-modify)
* [The verbs](#the-verbs)
  * [Setters](#setters)
  * [Select setters](#select-setters)
  * [`bazel_target_add`](#bazel_target_add)
  * [`bazel_target_add_select`](#bazel_target_add_select)
* [Rules](#rules)
* [Real-world examples](#real-world-examples)
  * [Disabling `alwayslink` on a static xcframework import](#disabling-alwayslink-on-a-static-xcframework-import)
  * [Adding compiler options to a single target](#adding-compiler-options-to-a-single-target)
* [Caveat](#caveat)
<!-- MARKDOWN TOC: END -->

## What this is

`rules_swift_package_manager` generates all of the Bazel declarations for the Swift packages that it
builds. The `swift_deps` module extension provides tags, modeled on `buildozer` commands, that edit
attributes on those generated declarations from your root `MODULE.bazel`. There are four verbs:

- **set** replaces (or creates) an attribute.
- **set_select** replaces (or creates) an attribute with a `select()`.
- **add** appends values to a list attribute.
- **add_select** appends a `select()` to a list attribute.

Nothing is parsed or guessed. Each `set` and `set_select` verb has one tag per value type, and you
pick the tag that matches the type the attribute wants:

| Tag                                                   | Value type                        |
| ----------------------------------------------------- | --------------------------------- |
| `swift_deps.bazel_target_set_bool`                    | `bool`                            |
| `swift_deps.bazel_target_set_int`                     | `int`                             |
| `swift_deps.bazel_target_set_string`                  | `string`                          |
| `swift_deps.bazel_target_set_string_list`             | `list` of `string`                |
| `swift_deps.bazel_target_set_string_dict`             | `dict` of `string` to `string`    |
| `swift_deps.bazel_target_set_select_bool_dict`        | `select()` with `bool` branches   |
| `swift_deps.bazel_target_set_select_int_dict`         | `select()` with `int` branches    |
| `swift_deps.bazel_target_set_select_string_dict`      | `select()` with `string` branches |
| `swift_deps.bazel_target_set_select_string_list_dict` | `select()` with `list` branches   |
| `swift_deps.bazel_target_add`                         | `list` of `string`                |
| `swift_deps.bazel_target_add_select`                  | `select()` with `list` branches   |

This is a use-at-your-own-risk escape hatch. It reaches directly into generated output, there is no
allowlist of attribute names, and nothing checks that the attribute you name makes sense for the
rule you are editing.

**If you need these tags, `rules_swift_package_manager` is probably missing a real feature.** Please
[file an issue] describing what you were trying to do, even if the escape hatch unblocked you, so
that the ruleset can support it properly.

## Find the target to modify

Every Swift package is generated into its own repository named `@swiftpkg_<identity>`, where
`<identity>` is the package identity from the manifest with `-` replaced by `_`. For example, the
`swift-argument-parser` package is generated into `@swiftpkg_swift_argument_parser`.

Inside that repository, each Swift package target is generated as two declarations in the root
package:

- `<Name>.rspm` is the publicly advertised target. This is what you depend on from your own `BUILD`
  files, and it is usually just an alias or a thin wrapper.
- `<Name>.rspm.__impl` is the declaration that actually compiles or imports the code. Attributes
  such as `copts`, `defines`, and `alwayslink` live here.

Modification tags almost always name the `.__impl` declaration.

To see what was actually generated:

```sh
# List the generated declarations, with their attributes.
$ bazel query --output=build 'kind(rule, @swiftpkg_example//:all)'

# Or read the generated build file directly.
$ find "$(bazel info output_base)/external" -maxdepth 1 -name '*swiftpkg_example'
```

All generated declarations live in the root package of the generated repository, so the `target`
value must be of the form `@repo_name//:target_name`.

## The verbs

### Setters

A setter replaces the attribute, creating it if the generated declaration does not have it. Pick the
tag whose type matches the value you want to write.

```bazel
swift_deps.bazel_target_set_bool(
    attr = "alwayslink",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    value = False,
)

swift_deps.bazel_target_set_int(
    attr = "shard_count",
    target = "@swiftpkg_example//:ExampleTests.rspm.__impl",
    value = 4,
)

swift_deps.bazel_target_set_string(
    attr = "module_name",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    value = "CustomExample",
)

swift_deps.bazel_target_set_string_list(
    attr = "copts",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    value = ["-DEXAMPLE_FEATURE"],
)

swift_deps.bazel_target_set_string_dict(
    attr = "env",
    target = "@swiftpkg_example//:ExampleTests.rspm.__impl",
    value = {"EXAMPLE_MODE": "strict"},
)
```

An empty value is allowed, so `value = []` clears a list attribute and `value = ""` writes an empty
`string`.

### Select setters

A select setter replaces the attribute with a `select()`. No `//conditions:default` branch is added
for you, so add one yourself if the attribute needs a value in unmatched configurations.

`bazel_target_set_select_string_dict` and `bazel_target_set_select_string_list_dict` write their
branch values as they are given: a `string` and a `list` of `string`, respectively.

```bazel
swift_deps.bazel_target_set_select_string_list_dict(
    attr = "copts",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    values = {
        "//:release_build": ["-DEXAMPLE_RELEASE_FEATURE"],
        "//conditions:default": [],
    },
)

swift_deps.bazel_target_set_select_string_dict(
    attr = "module_name",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    values = {
        "//:release_build": "ExampleRelease",
        "//conditions:default": "Example",
    },
)
```

`bazel_target_set_select_bool_dict` and `bazel_target_set_select_int_dict` take `string` branch
values because Bazel has no `bool` or `int` dictionary attribute, and convert them for you. A
`bool` branch must be exactly `True` or `False`, spelled the way Starlark spells them, and an `int`
branch must be digits with an optional leading `-`. Anything else fails when the module extension is
evaluated, with an error naming the target, the attribute, the condition and the bad value.

```bazel
swift_deps.bazel_target_set_select_bool_dict(
    attr = "alwayslink",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    values = {
        "//:release_build": "True",
        "//conditions:default": "False",
    },
)

swift_deps.bazel_target_set_select_int_dict(
    attr = "shard_count",
    target = "@swiftpkg_example//:ExampleTests.rspm.__impl",
    values = {
        "//:release_build": "8",
        "//conditions:default": "2",
    },
)
```

### `bazel_target_add`

Appends to a list attribute, creating the attribute if it is absent. Unlike the setters, this verb is
list-only and requires at least one value. The values land _after_ the generated values, so options
that follow last-option-wins semantics (e.g. `copts`) override what `rules_swift_package_manager`
generated.

```bazel
swift_deps.bazel_target_add(
    attr = "copts",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    values = ["-DEXAMPLE_FEATURE"],
)
```

### `bazel_target_add_select`

Appends a `select()` to a list attribute, preserving the generated value. The attribute renders as
`<generated> + select({...})`. Branch values are lists, and a `//conditions:default` branch with no
values is added when you do not provide one.

```bazel
swift_deps.bazel_target_add_select(
    attr = "copts",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    values = {"//:release_build": ["-DEXAMPLE_RELEASE_FEATURE"]},
)
```

## Rules

- **Root module only.** A non-root module that declares one of these tags fails the build.
- **At most one setter per target and attribute.** You may declare only one `bazel_target_set_*` or
  `bazel_target_set_select_*` tag for a given target attribute, across all nine of them. The `add`
  verbs are unlimited.
- **Ordering is by verb, not by declaration order.** The setter is applied first, then every
  `bazel_target_add` in declaration order, then every `bazel_target_add_select` in declaration
  order.
- **Setters accept empty values; the other verbs do not.** `value = []`, `value = ""` and
  `value = {}` are all fine and are written as-is. `bazel_target_add` requires at least one value,
  and every `select()` verb requires at least one condition.
- **The `add` verbs are list-only.** They take a `list` of `string` (or a `select()` whose branches
  are lists). To write a scalar, a `dict`, or a scalar-branched `select()`, use a setter.
- **`select()` keys are canonicalized.** Keys must be absolute labels. A key that is relative to the
  main repository (e.g. `//:release_build`) is rewritten to its canonical form (e.g.
  `@@//:release_build`) so that it still resolves from inside the generated repository. Make sure
  the `config_setting` is visible to external repositories.
- **`select()` keys may not use an apparent repository name.** A key such as
  `@some_repo//:setting` is rejected. An apparent name (a single `@`) is resolved using the
  repository mapping of whichever repository contains the label, and the key ends up inside a
  generated repository, so it would resolve against `rules_swift_package_manager`'s mapping instead
  of yours. Use a main-repository-relative label (`//:setting`), which is canonicalized for you, or
  a canonical label (`@@some_repo+//:setting`).
- **Values are emitted verbatim; labels in them are not remapped.** A value is written into the
  generated `BUILD.bazel` file as-is, so a label-valued string such as `//:my_lib` in `deps`
  resolves inside the generated repository, not in your root module. Use `@@//:my_lib` for a target
  in the main repository, or a canonical `@@repo+//:target` label for one in another repository.
- **The `name` attribute may not be modified.** The name of a generated declaration is written
  separately from its other attributes, so modifying it would emit a duplicate `name` keyword.
- **Incompatible with a complete build file override.** These tags cannot be combined with
  `configure_package(build_file = ...)` for the same package, because that override bypasses the
  generated declarations entirely.
- **Errors fail fast.** An unknown repository name lists the repositories that were generated, an
  unknown target name lists the declarations available in that repository, and conflicting setters
  list the conflicting target attributes.
- **Attribute names are not validated.** An attribute that the generated rule does not understand
  fails later, when Bazel loads the generated `BUILD.bazel` file, with Bazel's own error message.

## Real-world examples

### Disabling `alwayslink` on a static xcframework import

`rules_swift_package_manager` sets `alwayslink = True` on every generated
`apple_static_xcframework_import`. A few prebuilt SDKs ship an archive containing an object that
nothing references and whose symbols nothing can resolve. Force-loading pulls it in and the link
fails, even though the same SDK links fine under Swift package manager and Xcode. See
[issue #2445].

```bazel
swift_deps.bazel_target_set_bool(
    attr = "alwayslink",
    target = "@swiftpkg_facebook_ios_sdk//:FBAudienceNetwork.rspm.__impl",
    value = False,
)
```

### Adding compiler options to a single target

Sometimes one package target needs a compile-time flag that the manifest does not express, such as
compiling production-only bookkeeping out of a single runtime target without touching its siblings.
See [pull request #2439].

```bazel
swift_deps.bazel_target_add(
    attr = "copts",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    values = ["-DEXAMPLE_DISABLE_BOOKKEEPING"],
)
```

## Caveat

The names and the layout of the generated targets are implementation details. They can change
between releases of `rules_swift_package_manager`, which means that your overrides may need to be
updated when you upgrade. This is another reason to [file an issue] instead of relying on these tags
long-term.

[file an issue]: https://github.com/cgrindel/rules_swift_package_manager/issues
[issue #2445]: https://github.com/cgrindel/rules_swift_package_manager/issues/2445
[pull request #2439]: https://github.com/cgrindel/rules_swift_package_manager/pull/2439
