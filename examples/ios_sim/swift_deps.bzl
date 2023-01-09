load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 2.37.0
    swift_package(
        name = "swiftpkg_swift_nio",
        commit = "51c3fc2e4a0fcdf4a25089b288dd65b73df1b0ef",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-nio.git",
    )
