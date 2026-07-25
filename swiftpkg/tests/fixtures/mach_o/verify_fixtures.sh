#!/usr/bin/env bash

# Verifies that the byte reads recorded in `fixtures.bzl` still match what the
# `od` utility reports for the checked-in Mach-O fixtures.
#
# The Starlark tests for `mach_o` feed the recordings in `fixtures.bzl` to a
# fake reader, which cannot notice if those recordings stop describing a real
# binary or if `od` behaves differently on another platform. This test closes
# that gap. It runs on both Linux and macOS in CI, so it covers GNU `od` and
# BSD `od`, including the exact flags that `repository_files.read_bytes` uses.

set -o errexit -o nounset -o pipefail

fixtures_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixtures_bzl="${fixtures_dir}/fixtures.bzl"

if [[ ! -f ${fixtures_bzl} ]]; then
  echo >&2 "error: ${fixtures_bzl} was not found."
  exit 1
fi

# Mirrors `repository_files.read_bytes`: read `count` bytes at `offset` and
# normalize the output to space-separated lowercase hexadecimal bytes.
read_bytes() {
  local path="$1" offset="$2" count="$3"
  od -A n -t x1 -j "${offset}" -N "${count}" "${path}" \
    | tr '\n\t\r' '   ' | tr -s ' ' | sed -e 's/^ //' -e 's/ $//'
}

# Flattens fixtures.bzl into "<name> <offset> <count> <byte>..." records.
parse_recordings() {
  awk '
    /name = "/ {
      match($0, /name = "[^"]+"/)
      name = substr($0, RSTART + 8, RLENGTH - 9)
    }
    /^ *"[0-9]+:[0-9]+": \[/ {
      match($0, /"[0-9]+:[0-9]+"/)
      key = substr($0, RSTART + 1, RLENGTH - 2)
      split(key, parts, ":")
      bytes = ""
      n = split($0, tokens, "\"")
      # Tokens alternate between separators and quoted strings. The first
      # quoted string is the key; the rest are the recorded bytes.
      for (i = 4; i <= n; i += 2) {
        bytes = bytes " " tokens[i]
      }
      print name, parts[1], parts[2] bytes
    }
  ' "${fixtures_bzl}"
}

failures=0
checked=0

while read -r name offset count expected_bytes; do
  fixture="${fixtures_dir}/${name}"
  if [[ ! -e ${fixture} ]]; then
    echo >&2 "FAIL: fixture ${name} was not found at ${fixture}"
    failures=$((failures + 1))
    continue
  fi

  actual_bytes="$(read_bytes "${fixture}" "${offset}" "${count}")"
  checked=$((checked + 1))

  if [[ ${actual_bytes} != "${expected_bytes}" ]]; then
    echo >&2 "FAIL: ${name} at offset ${offset} (${count} bytes)"
    echo >&2 "  expected: ${expected_bytes}"
    echo >&2 "  actual:   ${actual_bytes}"
    failures=$((failures + 1))
  fi
done < <(parse_recordings)

if [[ ${checked} -eq 0 ]]; then
  echo >&2 "error: no recordings were parsed from ${fixtures_bzl}."
  exit 1
fi

if [[ ${failures} -gt 0 ]]; then
  echo >&2 ""
  echo >&2 "${failures} recording(s) no longer match the fixtures."
  echo >&2 "Regenerate them with:"
  echo >&2 "  swiftpkg/tests/fixtures/mach_o/gen_fixtures.sh"
  exit 1
fi

echo "OK: verified ${checked} recorded read(s) against the local od."
