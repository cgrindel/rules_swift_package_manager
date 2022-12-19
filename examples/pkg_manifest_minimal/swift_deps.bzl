load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "local_swift_package", "swift_package")

def swift_dependencies():
    local_swift_package(
        name = "swiftpkg_my_local_package",
        module_index = "@//:module_index.json",
        path = "/Users/chuck/code/cgrindel/swift_bazel/support_local_packages/examples/pkg_manifest_minimal/third_party/my_local_package",
    )

    # version: 1.2.0
    swift_package(
        name = "swiftpkg_swift_argument_parser",
        commit = "fddd1c00396eed152c45a46bea9f47b98e59301d",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-argument-parser",
    )

    # version: 1.4.4
    swift_package(
        name = "swiftpkg_swift_log",
        commit = "6fe203dc33195667ce1759bf0182975e4653ba1c",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-log",
    )

    # version: 0.50.6
    swift_package(
        name = "swiftpkg_swiftformat",
        commit = "da637c398c5d08896521b737f2868ddc2e7996ae",
        module_index = "@//:module_index.json",
        remote = "https://github.com/nicklockwood/SwiftFormat",
    )
