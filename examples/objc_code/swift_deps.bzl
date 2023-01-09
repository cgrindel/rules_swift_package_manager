load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 2.0.1
    swift_package(
        name = "swiftpkg_trustkit",
        commit = "65d573e0e2687ea91ab0b1be377f9dd3eb1c2785",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/datatheorem/TrustKit.git",
    )
