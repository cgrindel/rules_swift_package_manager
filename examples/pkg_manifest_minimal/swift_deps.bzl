load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 1.2.0
    swift_package(
        name = "apple_swift_argument_parser",
        commit = "fddd1c00396eed152c45a46bea9f47b98e59301d",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-argument-parser",
    )

    # version: 1.4.4
    swift_package(
        name = "apple_swift_log",
        commit = "6fe203dc33195667ce1759bf0182975e4653ba1c",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-log",
    )

    # version: 0.50.6
    swift_package(
        name = "nicklockwood_SwiftFormat",
        commit = "da637c398c5d08896521b737f2868ddc2e7996ae",
        module_index = "@//:module_index.json",
        remote = "https://github.com/nicklockwood/SwiftFormat",
    )
