# GRDB Example

This example demonstrates using [GRDB.swift](https://github.com/groue/GRDB.swift), a Swift
toolkit for SQLite databases, with `rules_swift_package_manager`.

This example is tested on both macOS and Linux.

## Linux Prerequisites

On Linux, SQLite development libraries are required:

```sh
# Ubuntu/Debian
sudo apt install sqlite3 libsqlite3-dev

# Fedora/RHEL
sudo dnf install sqlite sqlite-devel
```

## Linux Configuration

GRDB assumes that system SQLite includes snapshot support (`SQLITE_ENABLE_SNAPSHOT`), which is
true on macOS but not on most Linux distributions. This example uses `configure_package` with
`patch_cmds` in `MODULE.bazel` to:

1. Remove the `SQLITE_ENABLE_SNAPSHOT` define from GRDB's `Package.swift`
2. Add `GRDBCUSTOMSQLITE` define to disable the "system SQLite" code path

This allows GRDB to work correctly with Linux's system SQLite which doesn't include the
`sqlite3_snapshot_*` functions.

## Run the Example

```sh
# Generate build files
bazel run //:tidy

# Build
bazel build //...

# Run the example binary
bazel run //Sources/GRDBExample
```

## Docker Testing

To test on Linux using Docker:

```sh
./docker_test.sh
```

## What This Example Demonstrates

- Using GRDB.swift with Bazel on Linux and macOS
- Creating an in-memory SQLite database
- Defining Swift Codable models that work with GRDB
- Basic CRUD operations using GRDB's type-safe API
- Patching Swift packages for Linux compatibility using `configure_package`
