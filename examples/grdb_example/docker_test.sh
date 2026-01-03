#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Building Docker image..."
docker build -t grdb-example-test "${SCRIPT_DIR}"

echo "Running test in Docker container..."
docker run --rm \
    -e CC=clang \
    -v "${REPO_ROOT}:/workspace/repo:ro" \
    -w /workspace \
    grdb-example-test \
    bash -c '
        set -o errexit -o nounset -o pipefail

        # Copy the entire repo to a writable location (needed for .bazelrc imports)
        echo "=== Copying repository to writable location ==="
        cp -r /workspace/repo /workspace/rules_swift_package_manager
        cd /workspace/rules_swift_package_manager/examples/grdb_example

        # Remove symlinks and lock file that point to macOS paths
        rm -f bazel-* MODULE.bazel.lock 2>/dev/null || true

        # Clean external repos to ensure patches are applied fresh
        echo "=== Cleaning bazel cache ==="
        bazel clean --expunge || true

        echo "=== Running swift package resolve ==="
        bazel run //:update_swift_packages

        echo "=== Running tidy ==="
        bazel run //:tidy

        echo "=== Building ==="
        bazel build //...

        echo "=== Running example ==="
        bazel run //Sources/GRDBExample

        echo "=== SUCCESS: GRDB example works on Linux! ==="
    '
