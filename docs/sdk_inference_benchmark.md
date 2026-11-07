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

## Results

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

## Decision and limits

Keep SDK/compiler input tracking so changed compiler or SDK contents invalidate
the fetch-time result. This has a significant first-fetch and restarted-server
cost, even though the inventory is shared across packages. It is not equivalent
to watching only Xcode's version string. Changing the configured Xcode or watched
inputs can also regenerate opted-in packages, including download and SwiftPM
work. No zero-refetch or cross-host reproducibility guarantee is made.

Xcode 27.2 CI remains the authoritative Apple integration check. A larger-package
benchmark is still needed to characterize the additional per-target scan cost.

## Reproducing

Run from `examples/explicit_modules_example` with both provider and consumer
installed. Select a concrete Xcode path appropriate for the machine:

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
