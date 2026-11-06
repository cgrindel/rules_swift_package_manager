# SDK inventory adapter

The `rspm_sdk_inventory` repository adapts rules_swift's generated SDK targets
into compact metadata for dependency inference. It is declared lazily: importing
its extension does not fetch or scan an SDK. When `system_sdk_deps` is enabled, package contexts receive this metadata before
SwiftPM runs. Disabled inference and complete BUILD overrides do not read it.
The adapter alone does not scan package sources or change generated dependencies;
source inference is provided by the separate consumer PR.

## Contract

The repository exports `modules.json` with schema version 1:

```json
{
  "conditions": {
    "0": {
      "condition": "@@<inventory-repo>//:<xcode>_<sdk>",
      "configurations": {
        "debug": "@@<inventory-repo>//:<xcode>_<sdk>_debug",
        "release": "@@<inventory-repo>//:<xcode>_<sdk>_release"
      },
      "environment": "simulator",
      "platform": "ios"
    }
  },
  "diagnostic": "",
  "modules": {"Foundation": ["0"]},
  "schema_version": 1
}
```

Module entries reference a shared condition table. Consumers resolve only the
modules they encounter rather than expanding the complete inventory. Conditions
combine the hub's public Xcode selectors with the actual SDK constraints copied
from rules_swift's private SDK config settings. Device and simulator availability
are separate, as are different Xcode versions. Debug/release groups additionally
use RSPM's existing SwiftPM configuration settings.

An unsupported upstream layout produces an empty inventory with a persisted
`diagnostic` and a fetch-time warning. Consumers must surface that diagnostic
when inference is requested. A schema-version mismatch between this repository
and its reader is an error, rather than silently misinterpreting metadata.

## Upstream compatibility

rules_swift does not currently publish structured per-SDK availability metadata.
This adapter parses its generated hub and per-Xcode BUILD files. Parsing is
isolated in `swiftpkg/internal/sdk_inventory/parser.bzl`; repository reads, label resolution and
output generation live in `swiftpkg/internal/sdk_inventory/repository.bzl`. Tests include unmodified
blocks captured from rules_swift 4.2.2 output on Xcode 27.0 and verified unchanged
against rules_swift 4.2.1, alongside synthetic
multi-Xcode and device-only cases.

The adapter relies on both the generated BUILD syntax and the standard
`system_sdk` extension's sibling repository naming. Canonical repository-name
formatting is not a stable Bazel API. Replacement hubs and unsupported layouts
are not supported. Maintainers must accept this interim coupling before merging;
a structured metadata interface exported by rules_swift should replace it.

## Reproducibility and fetching

The adapter reads upstream files through `repository_ctx.read`, so Bazel tracks
those inputs and invalidates the inventory when they change. It does not run its
own Xcode locator or compiler. The non-Apple upstream stub yields no modules.

Fetching the inventory can fetch every Xcode SDK repository referenced by the
hub. Each BUILD file is parsed once in this shared repository, rather than once
per Swift package. Upstream changes can still invalidate consuming package
repositories. This is tracked host-dependent configuration, not an inventory
that is identical on arbitrary machines.

For a stable inventory, configure rules_swift's root
`system_sdk.configure_xcode` with precomputed BUILD files and explicitly select
the SDKs and exclusions. The root module owns this configuration. RSPM imports
`system_sdk` into its repository mapping but does not choose a build Xcode or
observe `--xcode_version` at repository time; generated conditions defer that
selection to Bazel analysis.

See [proposal #2488](https://github.com/cgrindel/rules_swift_package_manager/discussions/2488)
and the [inventory interface discussion](https://github.com/cgrindel/rules_swift_package_manager/pull/2576#issuecomment-6191433506).
