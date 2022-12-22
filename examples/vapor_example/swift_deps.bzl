load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 4.67.5
    swift_package(
        name = "swiftpkg_vapor",
        commit = "eb2da0d749e185789970c32f7fd9c114a339fa13",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/vapor.git",
    )
