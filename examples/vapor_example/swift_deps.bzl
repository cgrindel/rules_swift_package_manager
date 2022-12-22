load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 4.6.0
    swift_package(
        name = "swiftpkg_fluent",
        commit = "2da106f46b093885f77fa03e3c719ab5bb8cfab4",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/fluent.git",
    )

    # version: 4.3.0
    swift_package(
        name = "swiftpkg_fluent_sqlite_driver",
        commit = "7f2a0b105e9cd22141dee220848d8739da6b7232",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/fluent-sqlite-driver.git",
    )

    # version: 4.67.5
    swift_package(
        name = "swiftpkg_vapor",
        commit = "eb2da0d749e185789970c32f7fd9c114a339fa13",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/vapor.git",
    )
