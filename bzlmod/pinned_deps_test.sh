#!/usr/bin/env bash

# Verifies that every dependency pinned with `exact:` in the bzlmod workspace's
# Package.swift resolves to that same version in its Package.resolved.
#
# The BCR presubmit runs //bzlmod:e2e_test with an older Swift, so the
# workspace pins dependencies whose newer manifests it cannot parse. Renovate
# rewrites matching pins in every Package.resolved in the repository without
# checking Package.swift, which silently undoes those pins. This test catches
# that drift in regular CI.

set -o errexit -o nounset -o pipefail

package_swift="${1}"
package_resolved="${2}"

fail() {
  echo >&2 "FAIL: ${*}"
  exit 1
}

# Print "<url> <version>" for each uncommented `.package(url:, exact:)` line.
exact_pins="$(
  sed -nE \
    -e '/^[[:space:]]*\/\//d' \
    -e 's/.*\.package\(url: *"([^"]+)", *exact: *"([^"]+)"\).*/\1 \2/p' \
    "${package_swift}"
)"
[[ -n ${exact_pins} ]] \
  || fail "No exact pins found in ${package_swift}. Update this test if the" \
    "pins moved or changed format."

# Print the pinned version for the package at the given URL.
resolved_version() {
  local url="${1}"
  awk -v url="${url}" '
    /"location" *: *"/ {
      loc = $0
      sub(/.*"location" *: *"/, "", loc)
      sub(/".*/, "", loc)
    }
    /"version" *: *"/ && loc == url {
      ver = $0
      sub(/.*"version" *: *"/, "", ver)
      sub(/".*/, "", ver)
      print ver
      exit
    }
  ' "${package_resolved}"
}

while read -r url expected; do
  actual="$(resolved_version "${url}")"
  [[ ${actual} == "${expected}" ]] \
    || fail "${url} is pinned to ${expected} in Package.swift, but" \
      "Package.resolved has '${actual}'. Run" \
      "'bazel run //:update_swift_packages' in bzlmod/workspace."
  echo "OK: ${url} ${expected}"
done <<<"${exact_pins}"
