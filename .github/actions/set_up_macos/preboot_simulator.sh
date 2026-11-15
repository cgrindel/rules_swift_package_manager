#!/usr/bin/env bash

# Creates and boots the simulator that rules_apple's test runner will reuse, so
# the slow and occasionally failing first boot happens before any test runs.
#
# The device name and lookup mirror rules_apple's
# apple/testing/default_runner/simulator_creator.py (reuse_simulator=True):
# the runtime is the available iOS runtime whose version equals the requested
# OS version, and the device is named BAZEL_TEST_<device type>_<os version>.
#
# Usage: preboot_simulator.sh <device type> <os version>
# Example: preboot_simulator.sh "iPhone 16" 27.0

set -o errexit -o nounset -o pipefail

if [[ ${#} -ne 2 ]]; then
  echo >&2 "Usage: ${0} <device type> <os version>"
  exit 1
fi

device_type="${1}"
os_version="${2}"
device_name="BAZEL_TEST_${device_type}_${os_version}"
max_attempts=3

log() {
  echo "[$(date -u +%H:%M:%S)] ${*}"
}

# Same selection as rules_apple: an available iOS runtime whose version equals
# the requested OS version.
find_runtime_identifier() {
  xcrun simctl list runtimes -j | python3 -c '
import json, sys
os_version = sys.argv[1]
for runtime in json.load(sys.stdin)["runtimes"]:
    if (
        runtime["platform"] == "iOS"
        and runtime["isAvailable"]
        and runtime["version"] == os_version
    ):
        print(runtime["identifier"])
        break
' "${os_version}"
}

# Prints "<udid> <state>" for the device with the expected name under the
# runtime, matching how rules_apple looks up a simulator to reuse.
find_device() {
  xcrun simctl list devices -j | python3 -c '
import json, sys
runtime_identifier, device_name = sys.argv[1], sys.argv[2]
devices = json.load(sys.stdin)["devices"].get(runtime_identifier) or []
for device in devices:
    if device["name"] == device_name:
        print(device["udid"], device["state"])
        break
' "${runtime_identifier}" "${device_name}"
}

runtime_identifier="$(find_runtime_identifier)"
if [[ -z ${runtime_identifier} ]]; then
  # Fall back to the conventional identifier so the failure below names it.
  runtime_identifier="com.apple.CoreSimulator.SimRuntime.iOS-${os_version//./-}"
  log "No available iOS ${os_version} runtime found;" \
    "trying ${runtime_identifier}"
fi
log "Pre-booting '${device_name}' (${device_type}, ${runtime_identifier})"

for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  log "Attempt ${attempt} of ${max_attempts}"

  udid=""
  state=""
  read -r udid state < <(find_device) || true
  if [[ -n ${udid} ]]; then
    log "Reusing existing simulator ${udid} (state: ${state})"
    if [[ ${state} == "Booted" ]]; then
      log "Simulator is already booted"
      exit 0
    fi
  else
    if ! udid="$(xcrun simctl create \
      "${device_name}" "${device_type}" "${runtime_identifier}")"; then
      log "Failed to create simulator"
      continue
    fi
    log "Created simulator ${udid}"
  fi

  if xcrun simctl bootstatus "${udid}" -b; then
    log "Simulator ${udid} booted"
    exit 0
  fi

  log "Boot failed for ${udid}; shutting down and deleting it"
  xcrun simctl shutdown "${udid}" || true
  xcrun simctl delete "${udid}" || true
done

log "Failed to boot '${device_name}' after ${max_attempts} attempts"
exit 1
