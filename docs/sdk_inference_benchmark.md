# SDK inference fetch measurements

These measurements cover the shared SDK provider and the small
`examples/explicit_modules_example` fixture with the source-inference consumer
installed. They are not a Firebase or large dependency-graph benchmark.

## Environment and method

- Apple Silicon macOS host, Xcode 27.0 (27A266a), Bazel 9.3.2.
- Profiles: `MacOSX=arm64-apple-macosx13.0` and
  `iPhoneSimulator=arm64-apple-ios15.0-simulator`.
- Target: `//:inference_report_test`, using `--config=inferred_modules`.
- The first run used a new Bazel output base. Shared download caches and OS file
  caches were not cleared. The next run reused the server and output base; the
  third reused the output base after shutting down that server.
- Wall times include Bazel startup, loading, analysis and the report test. The
  report test does not compile the application or precompile its SDK modules.
- These are individual local observations, not a controlled comparison of
  implementations or a prediction of CI performance.

## Original full-tracking report test

| Invocation | Wall time | Inventory regenerated? | Package prescans rerun? |
| --- | ---: | --- | --- |
| Fresh output base | 206.39 s | Yes | Yes |
| Unchanged, same server | 0.76 s | No | No |
| Unchanged, restarted server | 43.62 s | No | No |

The fresh run spent 200.58 seconds in the inventory repository implementation,
including 186.62 seconds in SDK/compiler input traversal and watch registration.
The two Swift targets' compiler scan functions took about 0.48 seconds combined.

The watched manifest contained 48,337 distinct canonical file paths and 71,203
logical layout entries. The file paths account for 3,670,254,173 bytes of logical
content (3.67 GB / 3.42 GiB), including the selected SDKs, toolchain libraries,
compiler and developer framework directories. This is content size, not allocated
disk usage. The internal `scan_inputs.json` manifest was 34,254,329 bytes; package
repositories consume the compact `modules.json`, not that manifest.

The restarted-server run includes revalidation of the saved watched inputs as
well as startup and ordinary reanalysis. Its 43.62 seconds must not be attributed
entirely to hashing SDK files. The profile shows no inventory implementation or
package scan execution, and the test result was cached.

## Controlled tracking comparison

A follow-up on the same machine used three copies of the same example and a new
output base per copy. The modes were `system_sdk_deps = False`, inference enabled
with default identity tracking, and inference enabled with
`full_sdk_tracking = True`. The target was the generated package's `BUILD.bazel`
source file, forcing package generation without compiling the application, SDK
modules or a test runner. All modes used the same flags and two SDK profiles.

| Tracking mode | Fresh output base | Unchanged, same server | Unchanged, restarted server |
| --- | ---: | ---: | ---: |
| Inference disabled | 4.86 s | 0.17 s | 1.28 s |
| Identity (default) | 9.66 s | 0.19 s | 1.46 s |
| Full contents (opt-in) | 248.21 s | 0.65 s | 43.42 s |

The full provider took 243.18 seconds, with 228.94 seconds in traversal/watch
registration. Identity tracking took 5.44 seconds in the provider, including
0.29 seconds in traversal/watch registration. The two targets' package prescans
took 0.49 seconds with identity tracking and 0.50 seconds with full tracking.
Neither the provider implementation nor the package prescans reran after restart.
The disabled control did not fetch the inventory.

| Watched manifest | Identity | Full |
| --- | ---: | ---: |
| Canonical files | 4 | 48,338 |
| Logical layout entries | 4 | 71,206 |
| Logical content bytes | 173,129,537 | 3,670,254,703 |
| `scan_inputs.json` bytes | 1,339 | 34,255,052 |

The default's four files are the compiler binary, Xcode version file and two SDK
settings files. The compiler resolves to a large binary, so identity tracking
still hashes about 173 MB; it is not free. The additional full-tracking file
compared with the original run is Xcode's version file.

The full restart exceeded the disabled control by 42.14 seconds, while identity
tracking exceeded it by 0.18 seconds. Along with the absence of regenerated
repositories, this strongly implicates input revalidation in the full mode's
restart cost. The difference still includes other loading/reanalysis work and
must not be described as an isolated hashing measurement.

These were single sequential runs (disabled, identity, full), with other local
Bazel validation paused. Shared download/repository caches and OS caches were
retained, and the order was not randomized. The target differs from the original
report-test measurement above, so compare modes within this table rather than
attributing changes between the two experiments to the implementation alone.

## Tracking policy

Full tracking is now opt-in (`sdk_inventory.configure(full_sdk_tracking = True)`).
The default watches and fingerprints only the compiler binary, Xcode's
`Contents/version.plist`, and each configured SDK's `SDKSettings.json`. It assumes
an unmodified Xcode installation; in-place edits to SDK headers, developer
frameworks or toolchain libraries require full tracking to invalidate scans.

Changing the configured Xcode or tracked inputs can regenerate opted-in packages,
including download and SwiftPM work. No zero-refetch or cross-host reproducibility
guarantee is made. Xcode 27.2 CI remains the authoritative Apple integration check.
A larger-package benchmark is still needed to characterize per-target scan cost.

## Reproducing

Run from `examples/explicit_modules_example` with both provider and consumer
installed. Set `full_sdk_tracking = True` on `sdk_inventory.configure(...)` to
reproduce the original full-tracking measurement; omit it to use identity tracking. Select a concrete Xcode path appropriate for the machine:

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.0.0.app/Contents/Developer
export USE_BAZEL_VERSION=9.3.2
benchmark_output_base=$(mktemp -d /tmp/rspm-sdk-bench.XXXXXX)

/usr/bin/time -p bazel --output_base="$benchmark_output_base" test \
  --config=inferred_modules --xcode_version=27.0.0 //:inference_report_test \
  --profile="$benchmark_output_base/cold.profile.gz"

/usr/bin/time -p bazel --output_base="$benchmark_output_base" test \
  --config=inferred_modules --xcode_version=27.0.0 //:inference_report_test \
  --profile="$benchmark_output_base/noop.profile.gz"

bazel --output_base="$benchmark_output_base" shutdown
/usr/bin/time -p bazel --output_base="$benchmark_output_base" test \
  --config=inferred_modules --xcode_version=27.0.0 //:inference_report_test \
  --profile="$benchmark_output_base/restart-noop.profile.gz"
```

Inspect `scan_inputs.json` in the generated `rspm_sdk_inventory` repository to
count `files` and `layout`. Sum the file sizes for `files`, which contains resolved
paths with directory cycles and aliases removed. Preserve all three profiles and
logs; a warm invocation alone does not measure cold input tracking.

For the controlled comparison, use three copies of the fixture, each with a
`local_path_override` pointing to the same ruleset checkout and the same Bazel rc
settings. Change only `system_sdk_deps` and `full_sdk_tracking` as described above.
For each mode, allocate a new output base and use the same cold/warm/shutdown/restart
sequence, replacing the test command with:

```sh
/usr/bin/time -p bazel --output_base="$benchmark_output_base" build \
  --config=inferred_modules --xcode_version=27.0.0 \
  @swiftpkg_explicitmodulesfixture//:BUILD.bazel \
  --profile="$benchmark_output_base/cold.profile.gz"
```

This intentionally requests a source-file target: its repository is generated,
but no compilation actions are executed. Preserve the profiles and manifest sizes
before running additional builds in those output bases.
