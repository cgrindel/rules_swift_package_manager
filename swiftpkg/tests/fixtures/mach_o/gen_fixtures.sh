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

for tool in clang lipo ar od; do
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
  od -A n -t x1 -j "${offset}" -N "${count}" "${path}" \
    | tr '\n\t\r' '   ' | tr -s ' ' | sed -e 's/^ //' -e 's/ $//'
}

# Walks the header chain exactly as `mach_o.link_type` does, emitting each
# read it performs and returning the resulting link type. Keeping the two in
# lockstep is what makes `fixtures.bzl` a faithful recording.
record_reads() {
  local path="$1"
  local offset=0 magic slice_off_hex

  for _ in 1 2; do
    magic="$(read_bytes "${path}" "${offset}" 4)"
    echo "            \"${offset}:4\": [$(hex_list "${magic}")],"
    case "${magic}" in
      "21 3c 61 72")
        echo "static"
        return 0
        ;;
      "cf fa ed fe" | "ce fa ed fe" | "fe ed fa cf" | "fe ed fa ce")
        local filetype
        filetype="$(read_bytes "${path}" "$((offset + 12))" 4)"
        echo "            \"$((offset + 12)):4\": [$(hex_list "${filetype}")],"
        case "${magic}" in
          # Little endian magic; the filetype is little endian too.
          "cf fa ed fe" | "ce fa ed fe")
            [[ ${filetype} == "06 00 00 00" ]] \
              && echo "dynamic" || echo "static"
            ;;
          *)
            [[ ${filetype} == "00 00 00 06" ]] \
              && echo "dynamic" || echo "static"
            ;;
        esac
        return 0
        ;;
      "ca fe ba be" | "ca fe ba bf")
        local size=4
        [[ ${magic} == "ca fe ba bf" ]] && size=8
        slice_off_hex="$(read_bytes "${path}" "$((offset + 16))" "${size}")"
        echo "            \"$((offset + 16)):${size}\": [$(hex_list \
          "${slice_off_hex}")],"
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
corresponding fixture, keyed by `"<offset>:<count>"`. `verify_fixtures.sh`
re-reads the fixtures with `od` and fails if these recordings drift, which is
what keeps them honest on both Linux and macOS.
"""

MACH_O_FIXTURES = [
EOF

  for name in thin_dylib thin_object thin_archive fat_dylib fat_archive \
    fat64_dylib symlinked_dylib; do
    reads_and_type="$(record_reads "${fixtures_dir}/${name}")"
    link_type="$(echo "${reads_and_type}" | tail -n 1)"
    reads="$(echo "${reads_and_type}" | sed '$d')"
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
