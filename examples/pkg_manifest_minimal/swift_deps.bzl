load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "local_swift_package", "swift_package")

def swift_dependencies():
    local_swift_package(
        name = "swiftpkg_my_local_package",
        dependencies_index = "@//:swift_deps_index.json",
        path = "third_party/my_local_package",
    )

    # version: 1.2.1
    swift_package(
        name = "swiftpkg_swift_argument_parser",
        commit = "4ad606ba5d7673ea60679a61ff867cc1ff8c8e86",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-argument-parser",
    )

    # version: 1.5.1
    swift_package(
        name = "swiftpkg_swift_log",
        commit = "3e3ef75109d6801b2c44504e73f55f0dce6662c9",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-log",
    )

    # version: 0.50.7
    swift_package(
        name = "swiftpkg_swiftformat",
        commit = "34cd9dd87b78048ce0d623a9153f9bf260ad6590",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/nicklockwood/SwiftFormat",
    )
