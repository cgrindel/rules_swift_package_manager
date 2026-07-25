# Mach-O Test Fixtures

These are real Mach-O binaries and `ar` archives used to test `swiftpkg/internal/mach_o.bzl`, which
determines whether a framework binary is statically or dynamically linked by reading the magic bytes
and the Mach-O `filetype` field.

All of them are compiled from a single trivial C source:

```c
int spm_fixture(void) { return 42; }
```

## The Fixtures

Each fixture covers a distinct header layout that `mach_o.link_type` has to walk. The thin binaries
are `arm64`; the universal binaries are `arm64` and `x86_64`.

| Fixture           | Built with            | Magic         | Covers                                  | Link type |
| ----------------- | --------------------- | ------------- | --------------------------------------- | --------- |
| `thin_dylib`      | `clang -dynamiclib`   | `cf fa ed fe` | `MH_DYLIB` (`filetype` 6)               | dynamic   |
| `thin_object`     | `clang -c`            | `cf fa ed fe` | `MH_OBJECT` (`filetype` 1)              | static    |
| `thin_archive`    | `ar rcs`              | `21 3c 61 72` | The `!<arch>` magic                     | static    |
| `fat_dylib`       | `lipo -create`        | `ca fe ba be` | 32-bit fat header wrapping a dylib      | dynamic   |
| `fat_archive`     | `lipo -create`        | `ca fe ba be` | 32-bit fat header wrapping an archive   | static    |
| `fat64_dylib`     | `lipo -create -fat64` | `ca fe ba bf` | 64-bit fat header, 8-byte slice offsets | dynamic   |
| `symlinked_dylib` | `ln -s thin_dylib`    | `cf fa ed fe` | Reading through a symlink               | dynamic   |

The two universal fixtures matter most. A fat header looks identical for both (`ca fe ba be`), so the
link type cannot be determined without following the slice offset into the first slice. `fat64_dylib`
covers the variant whose slice offsets are eight bytes wide rather than four.

`symlinked_dylib` exists because versioned macOS frameworks expose their binary through
`Versions/Current/<Name>`, so the reader has to follow symlinks. This is what the old implementation
used the `--dereference` flag of `file` for.

The fixture set is not exhaustive. 32-bit (`ce fa ed fe`) and big-endian (`fe ed fa cf`,
`fe ed fa ce`) headers, and the `MH_DYLIB_STUB` file type, are covered synthetically in
`//swiftpkg/tests:mach_o_tests` rather than by a fixture, because current toolchains cannot produce
them.

## How They Are Used

The fixtures feed two layers of tests:

1. `fixtures.bzl` records the bytes that `mach_o.link_type` reads from each fixture, keyed by
   `"<offset>:<count>"`, along with the expected link type. `//swiftpkg/tests:mach_o_tests` replays
   those recordings through a fake reader and asserts the resulting link type. This runs at analysis
   time, so it cannot touch the binaries directly.

   The expected link type is derived from `file` and `otool` — the utilities this ruleset used to
   depend on — and never from a second walk of the header. Recording it any other way would only
   prove that two copies of the same algorithm agree, which is precisely the failure these fixtures
   exist to catch.

2. `verify_fixtures.sh` re-reads the binaries with the real `od` utility, using the same flags as
   `repository_files.read_bytes`, and fails if the recordings in `fixtures.bzl` have drifted.

The second layer is what keeps the first honest. Because CI runs the test suite on both
`ubuntu-22.04` and `macos-15`, it also verifies that the `od` flags and output format behave the same
under GNU `od` and BSD `od`.

## Regenerating

```sh
$ swiftpkg/tests/fixtures/mach_o/gen_fixtures.sh
```

This rebuilds every binary and rewrites `fixtures.bzl`. It requires `clang`, `lipo`, `ar`, `od`,
`file`, and `otool`, so it must be run on macOS. The fixtures should rarely, if ever, need to change;
regenerate them only if a new header layout needs coverage.

Regenerating always produces byte-different `thin_archive` and `fat_archive` files, because `ar`
records a timestamp in each member header and Apple's `ar` has no deterministic mode. A diff limited
to those two files is expected and harmless.

## Why They Are Checked In

Two reasons.

First, a Mach-O dynamic library cannot be linked without the Apple SDK. The linker injects a
reference to `dyld_stub_binder`, which is resolved out of `libSystem`, and neither `-nostdlib` nor
`-undefined dynamic_lookup` avoids it. Since the SDK is not redistributable, a hermetic toolchain
could produce the object and archive fixtures but not `thin_dylib` — the one that actually exercises
the dynamic-versus-static decision.

Second, these are golden inputs, and golden inputs should be inert. If they were rebuilt from a
toolchain, a compiler upgrade could silently shift the bytes, and a test meant to detect drift in our
reader would start failing for reasons that have nothing to do with this ruleset.

Together the binaries total roughly 85 KB.
