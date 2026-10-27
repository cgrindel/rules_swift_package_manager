# Dependency inference configuration (part 2)

This release establishes configuration for future dependency inference. **Neither
setting currently scans imports or changes generated dependencies**, even when
set to `True` or `"on"`. Continue supplying missing dependencies with
`configure_package(target_deps = ...)`. Compiler features remain independently
configured as described in the [migration notes](rules_swift_4_migration.md).

## Root defaults and package overrides

Only the root Bazel module can set inference policy. Both defaults are false;
at most one `configure_explicit_modules` tag is allowed:

```starlark
swift_deps.configure_explicit_modules(
    system_sdk_deps = True,
    binary_target_deps = False,
)
swift_deps.configure_package(
    name = "some-package",
    system_sdk_deps = "off",
    binary_target_deps = "on",
)
```

Each package setting accepts `"inherit"` (the default), `"on"`, or `"off"`.
`inherit` uses the corresponding root default, or false when no global tag is
present. The two settings resolve independently. Package names use the existing
`configure_package` lookup: the dependency name is tried first, then the generated
repository name (for example `swiftpkg_some_package`). When both names have
explicit overrides, the dependency-name entry wins as a whole.

Non-root modules may continue using existing package configuration, with both
inference fields left at `inherit`. A non-root global tag or an explicit package
inference override is rejected. Multiple explicit inference overrides for the
same package name are rejected; put both fields in one tag. This ownership check
runs even if no package is fetched.

Resolved booleans are passed to Git, local, and registry repositories and stored
in the package generation context. Direct users of `swift_package`,
`local_swift_package`, and `registry_swift_package` may supply the same boolean
attributes, which also default to false.

A complete `build_file` override still bypasses generation. Existing
`bazel_target_set_*` and `bazel_target_add*` modifications still run last. Inference
configuration does not conflict with either mechanism, and does not change the
existing conflict between a full BUILD override and target modifications.

## Proposed SDK inventory contract — not an implemented API

Part 3 needs a supported inventory interface from rules_swift before it can
safely translate imports into dependencies. An internal list of module names is
insufficient: it does not establish which SDKs provide each module. The existing
RSPM framework catalog also omits non-framework modules and is tied to an older
SDK. Neither should become the authoritative inference inventory.

The proposed contract is a versioned, machine-readable file exported by the
configured `system_sdk` repository and readable at repository evaluation time.
Each entry should describe:

- The importable module name, including non-framework modules such as `Dispatch`.
- The public dependency label that consumers should use, with documented label
  resolution/repository-mapping semantics; no hard-coded canonical repo names.
- Availability by SDK and platform variant (device, simulator, and Catalyst where
  applicable), with architecture restrictions if relevant.
- The SDK configuration and identity the inventory describes. It must reflect
  configured SDK selection and exclusions, not just modules shipped by Xcode.

For discussion, a record could have `module_name`, `dependency_label`, and
`sdk_variants` fields under a top-level `schema_version`. These are proposed
field names, not a format RSPM parses today. We still need agreement with
rules_swift on the exported file label, label encoding, platform identifiers,
compatibility policy, and how unavailable or excluded modules are represented.
The design must avoid a repository-evaluation dependency cycle and allow Linux
consumers with inference disabled to continue without requiring an Apple SDK.

RSPM's repository mapping will need access to this inventory and its labels.
That mapping does not transfer ownership of SDK configuration: only the
consuming root module configures SDKs and exclusions. Explicit exclusions replace
rules_swift's defaults, as documented in the migration notes.

No inventory file is consumed, SDK repository mapping added, or compiler scanner
invoked by this change. Once the upstream contract is agreed and available,
part 3 can collect source imports, resolve platform-specific SDK labels, account
for generated resource accessors, and test builds with
`swift.add_default_precompiled_modules` disabled. Binary-framework inference is
a separate follow-up using its independent setting.

See the [part 2 plan](https://github.com/cgrindel/rules_swift_package_manager/pull/2576#issuecomment-6191433506)
and the [original proposal](https://github.com/cgrindel/rules_swift_package_manager/discussions/2488).
