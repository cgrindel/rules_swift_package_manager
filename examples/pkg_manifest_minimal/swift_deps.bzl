load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 1.2.0
    swift_package(
        name = "apple_swift_argument_parser",
        commit = "fddd1c00396eed152c45a46bea9f47b98e59301d",
        modules = {
            "ArgumentParser": "//Sources/ArgumentParser",
            "Generate_Manual": "//Plugins/GenerateManualPlugin:Generate Manual",
            "changelog_authors": "//Tools/changelog-authors",
            "count_lines": "//Examples/count-lines",
            "generate_manual": "//Tools/generate-manual",
            "math": "//Examples/math",
            "repeat": "//Examples/repeat",
            "roll": "//Examples/roll",
        },
        remote = "https://github.com/apple/swift-argument-parser",
    )

    # version: 1.4.4
    swift_package(
        name = "apple_swift_log",
        commit = "6fe203dc33195667ce1759bf0182975e4653ba1c",
        modules = {
            "Logging": "//Sources/Logging",
        },
        remote = "https://github.com/apple/swift-log",
    )
