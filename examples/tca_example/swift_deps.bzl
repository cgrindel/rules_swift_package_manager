load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 0.9.1
    swift_package(
        name = "swiftpkg_combine_schedulers",
        commit = "882ac01eb7ef9e36d4467eb4b1151e74fcef85ab",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/pointfreeco/combine-schedulers",
    )

    # version: 0.13.0
    swift_package(
        name = "swiftpkg_swift_case_paths",
        commit = "f623901b4bcc97f59c36704f81583f169b228e51",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/pointfreeco/swift-case-paths",
    )

    # version: 0.2.0
    swift_package(
        name = "swiftpkg_swift_clocks",
        commit = "20b25ca0dd88ebfb9111ec937814ddc5a8880172",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/pointfreeco/swift-clocks",
    )

    # version: 1.0.4
    swift_package(
        name = "swiftpkg_swift_collections",
        commit = "937e904258d22af6e447a0b72c0bc67583ef64a2",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-collections",
    )

    # version: 0.51.0
    swift_package(
        name = "swiftpkg_swift_composable_architecture",
        commit = "cd22f6a1b3a6210e1e365cbfa8706dbb1736ca27",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/pointfreeco/swift-composable-architecture",
    )

    # version: 0.8.0
    swift_package(
        name = "swiftpkg_swift_custom_dump",
        commit = "dd86159e25c749873f144577e5d18309bf57534f",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/pointfreeco/swift-custom-dump",
    )

    # version: 0.1.4
    swift_package(
        name = "swiftpkg_swift_dependencies",
        commit = "8282b0c59662eb38946afe30eb403663fc2ecf76",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/pointfreeco/swift-dependencies",
    )

    # version: 0.7.0
    swift_package(
        name = "swiftpkg_swift_identified_collections",
        commit = "ad3932d28c2e0a009a0167089619526709ef6497",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/pointfreeco/swift-identified-collections",
    )

    # version: 0.6.1
    swift_package(
        name = "swiftpkg_swiftui_navigation",
        commit = "270a754308f5440be52fc295242eb7031638bd15",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/pointfreeco/swiftui-navigation",
    )

    # version: 0.8.3
    swift_package(
        name = "swiftpkg_xctest_dynamic_overlay",
        commit = "62041e6016a30f56952f5d7d3f12a3fd7029e1cd",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/pointfreeco/xctest-dynamic-overlay",
    )
