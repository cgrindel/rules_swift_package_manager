#!/bin/bash

set -euo pipefail

#
# This is a templated script which runs `swift package <cmd>`.
#
# The expected template keys are:
#  %(swift_worker)s - The path to the Swift worker executable.
#  %(cmd)s - The command to run.
#  %(package)s - The path to the package to run the command on.
#  %(build_path)s - The path to the build directory.
#  %(cache_path)s - The path to the cache directory.

if [ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
  echo "BUILD_WORKSPACE_DIRECTORY is not set, this target may only be \`bazel run\`"
  exit 1
fi

# Collect template values.
swift_worker="%(swift_worker)s"
cmd="%(cmd)s"
package_path="$BUILD_WORKSPACE_DIRECTORY/%(package_path)s"
build_path="%(build_path)s"
cache_path="%(cache_path)s"
enable_build_manifest_caching="%(enable_build_manifest_caching)s"
enable_dependency_cache="%(enable_dependency_cache)s"
manifest_cache="%(manifest_cache)s"
security_path="%(security_path)s"

# Construct dynamic arguments.
args=()

if [ "$enable_build_manifest_caching" = "true" ]; then
  args+=("--enable-build-manifest-caching")
else
  args+=("--disable-build-manifest-caching")
fi

if [ "$enable_dependency_cache" = "true" ]; then
  args+=("--enable-dependency-cache")
else
  args+=("--disable-dependency-cache")
fi

args+=("--manifest-cache=$manifest_cache")

# Run the command.
"$swift_worker" swift package \
  --build-path "$build_path" \
  --cache-path "$cache_path" \
  --package-path "$package_path" \
  --security-path "$security_path" \
  "$cmd" \
  "${args[@]}" \
  "$@"
