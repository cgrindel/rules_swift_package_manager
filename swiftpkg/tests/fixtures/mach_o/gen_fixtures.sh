#!/usr/bin/env bash

# Regenerates the Mach-O fixtures and the recorded byte reads in
# `fixtures.bzl`.
#
# The fixtures are real Mach-O binaries and ar archives, compiled from a
# trivial C source. They are checked in so that the tests which consume them
# can run on any platform. This script requires clang and lipo, so it must be
# run on macOS.
#
# Usage: swiftpkg/tests/fixtures/mach_o/gen_fixtures.sh

set -o errexit -o nounset -o pipefail

fixtures_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

for tool in clang lipo ar od file otool; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo >&2 "error: ${tool} was not found. This script must run on macOS."
    exit 1
  fi
done

# MARK: - Build the binaries

echo 'int spm_fixture(void) { return 42; }' >"${work_dir}/fixture.c"

cd "${work_dir}"

# A thin arm64 dynamic library (MH_DYLIB).
clang -arch arm64 -Os -dynamiclib -o thin_dylib fixture.c
# A thin arm64 object file (MH_OBJECT).
clang -arch arm64 -Os -c -o thin_object fixture.c
# A thin arm64 static archive (ar).
ar rcs thin_archive thin_object
# The x86_64 counterparts, used to assemble the universal fixtures.
clang -arch x86_64 -Os -dynamiclib -o x86_dylib fixture.c
clang -arch x86_64 -Os -c -o x86_object fixture.c
ar rcs x86_archive x86_object
# A universal dynamic library and a universal static archive.
lipo -create thin_dylib x86_dylib -output fat_dylib
lipo -create thin_archive x86_archive -output fat_archive
# A 64-bit universal dynamic library, whose header uses 64-bit slice offsets.
lipo -create -fat64 thin_dylib x86_dylib -output fat64_dylib

strip -x thin_dylib fat_dylib fat64_dylib 2>/dev/null || true

for name in thin_dylib thin_object thin_archive fat_dylib fat_archive \
  fat64_dylib; do
  cp "${work_dir}/${name}" "${fixtures_dir}/${name}"
done

# A symlink to a dynamic library. Versioned macOS frameworks expose their
# binary through `Versions/Current`, so the reader must follow symlinks.
ln -sf thin_dylib "${fixtures_dir}/symlinked_dylib"

# MARK: - Record the byte reads

# Reads `count` bytes at `offset` and prints them as space-separated lowercase
# hexadecimal bytes. This mirrors `repository_files.read_bytes`.
read_bytes() {
  local path="$1" offset="$2" count="$3"
  od -A n -t x1 -v -j "${offset}" -N "${count}" "${path}" \
    | tr '\n\t\r' '   ' | tr -s ' ' | sed -e 's/^ //' -e 's/ $//'
}

# Determines the link type the way this ruleset used to, by way of the `file`
# and `otool` utilities.
#
# The expectation recorded for each fixture MUST come from ground truth rather
# than from a second implementation of the algorithm under test. Deriving it by
# walking the header here would only prove that two copies of the same logic
# agree, which is exactly the kind of mistake these fixtures exist to catch.
ground_truth_link_type() {
  local path="$1"
  if file -b "${path}" | grep -q "ar archive"; then
    echo static
  elif otool -l "${path}" 2>/dev/null | grep -q LC_ID_DYLIB; then
    echo dynamic
  else
    echo static
  fi
}

# The header prefix size that mach_o.link_type reads in a single call. Keep
# this in sync with _HEADER_PREFIX_SIZE in swiftpkg/internal/mach_o.bzl.
header_prefix_size=24

# Walks the header chain the way `mach_o.link_type` does, emitting each read it
# performs. This only determines WHICH bytes get recorded; the expected link
# type comes from ground_truth_link_type.
record_reads() {
  local path="$1"
  local offset=0 header magic slice_off_hex size

  for _ in 1 2; do
    header="$(read_bytes "${path}" "${offset}" "${header_prefix_size}")"
    echo "            \"${offset}:${header_prefix_size}\": [$(hex_list \
      "${header}")],"

    # shellcheck disable=SC2086
    set -- ${header}
    magic="$1 $2 $3 $4"

    case "${magic}" in
      "21 3c 61 72" | "cf fa ed fe" | "ce fa ed fe" | "fe ed fa cf" | \
        "fe ed fa ce")
        # An ar archive is decided by its magic alone, and a thin Mach-O by the
        # filetype already inside this prefix. Either way, no further read.
        return 0
        ;;
      "ca fe ba be" | "ca fe ba bf")
        size=4
        [[ ${magic} == "ca fe ba bf" ]] && size=8
        # The first slice's offset lives at byte 16 of the prefix.
        slice_off_hex="$(echo "${header}" | cut -d ' ' -f 17-$((16 + size)))"
        offset=$((16#$(echo "${slice_off_hex}" | tr -d ' ')))
        ;;
      *)
        echo >&2 "error: unrecognized magic '${magic}' in ${path}"
        exit 1
        ;;
    esac
  done

  echo >&2 "error: nested universal binary in ${path}"
  exit 1
}

# Formats space-separated hex bytes as a Starlark list body.
hex_list() {
  local out=""
  for byte in $1; do
    out="${out}\"${byte}\", "
  done
  echo "${out%, }"
}

{
  cat <<'EOF'
"""Recorded byte reads for the Mach-O fixtures.

DO NOT EDIT. Regenerate with:

    swiftpkg/tests/fixtures/mach_o/gen_fixtures.sh

Each entry records the bytes that `mach_o.link_type` reads from the
corresponding fixture, keyed by `"<offset>:<count>"`, along with the link type
that the `file` and `otool` utilities report for it. `verify_fixtures.sh`
re-reads the fixtures with `od` and fails if these recordings drift, which is
what keeps them honest on both Linux and macOS.
"""

MACH_O_FIXTURES = [
EOF

  for name in thin_dylib thin_object thin_archive fat_dylib fat_archive \
    fat64_dylib symlinked_dylib; do
    reads="$(record_reads "${fixtures_dir}/${name}")"
    link_type="$(ground_truth_link_type "${fixtures_dir}/${name}")"
    cat <<EOF
    struct(
        name = "${name}",
        exp_link_type = "${link_type}",
        reads = {
${reads}
        },
    ),
EOF
  done

  echo "]"
} >"${fixtures_dir}/fixtures.bzl"

echo "Wrote fixtures and ${fixtures_dir}/fixtures.bzl"
