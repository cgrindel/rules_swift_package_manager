load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 1.13.1
    swift_package(
        name = "swiftpkg_async_http_client",
        commit = "5bee16a79922e3efcb5cea06ecd27e6f8048b56b",
        module_index = "@//:module_index.json",
        remote = "https://github.com/swift-server/async-http-client.git",
    )

    # version: 1.15.0
    swift_package(
        name = "swiftpkg_async_kit",
        commit = "929808e51fea04f01de0e911ce826ef70c4db4ea",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/async-kit.git",
    )

    # version: 4.5.0
    swift_package(
        name = "swiftpkg_console_kit",
        commit = "a7e67a1719933318b5ab7eaaed355cde020465b1",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/console-kit.git",
    )

    # version: 4.6.0
    swift_package(
        name = "swiftpkg_fluent",
        commit = "2da106f46b093885f77fa03e3c719ab5bb8cfab4",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/fluent.git",
    )

    # version: 1.36.1
    swift_package(
        name = "swiftpkg_fluent_kit",
        commit = "be7912ee4991bcc8a5390fac0424d1d08221dcc6",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/fluent-kit.git",
    )

    # version: 4.3.0
    swift_package(
        name = "swiftpkg_fluent_sqlite_driver",
        commit = "7f2a0b105e9cd22141dee220848d8739da6b7232",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/fluent-sqlite-driver.git",
    )

    # version: 4.5.2
    swift_package(
        name = "swiftpkg_multipart_kit",
        commit = "0d55c35e788451ee27222783c7d363cb88092fab",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/multipart-kit.git",
    )

    # version: 4.6.0
    swift_package(
        name = "swiftpkg_routing_kit",
        commit = "ffac7b3a127ce1e85fb232f1a6271164628809ad",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/routing-kit.git",
    )

    # version: 3.23.0
    swift_package(
        name = "swiftpkg_sql_kit",
        commit = "dcf10a00d7d5df987b7948e6fd5596fb65f6d0c2",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/sql-kit.git",
    )

    # version: 4.2.0
    swift_package(
        name = "swiftpkg_sqlite_kit",
        commit = "c07d53044727db7edf8550c2e8ccfe1fa40177d2",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/sqlite-kit.git",
    )

    # version: 1.3.0
    swift_package(
        name = "swiftpkg_sqlite_nio",
        commit = "3b93e0a58643cc02a8bc42014fe462e1532df62d",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/sqlite-nio.git",
    )

    # version: 1.0.0
    swift_package(
        name = "swiftpkg_swift_algorithms",
        commit = "b14b7f4c528c942f121c8b860b9410b2bf57825e",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-algorithms.git",
    )

    # version: 1.0.3
    swift_package(
        name = "swiftpkg_swift_atomics",
        commit = "ff3d2212b6b093db7f177d0855adbc4ef9c5f036",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-atomics.git",
    )

    # version: 1.3.3
    swift_package(
        name = "swiftpkg_swift_backtrace",
        commit = "f25620d5d05e2f1ba27154b40cafea2b67566956",
        module_index = "@//:module_index.json",
        remote = "https://github.com/swift-server/swift-backtrace.git",
    )

    # version: 1.0.4
    swift_package(
        name = "swiftpkg_swift_collections",
        commit = "937e904258d22af6e447a0b72c0bc67583ef64a2",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-collections.git",
    )

    # version: 2.2.2
    swift_package(
        name = "swiftpkg_swift_crypto",
        commit = "92a04c10fc5ce0504f8396aac7392126033e547c",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-crypto.git",
    )

    # version: 1.4.4
    swift_package(
        name = "swiftpkg_swift_log",
        commit = "6fe203dc33195667ce1759bf0182975e4653ba1c",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-log.git",
    )

    # version: 2.3.3
    swift_package(
        name = "swiftpkg_swift_metrics",
        commit = "9b39d811a83cf18b79d7d5513b06f8b290198b10",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-metrics.git",
    )

    # version: 2.46.0
    swift_package(
        name = "swiftpkg_swift_nio",
        commit = "7e3b50b38e4e66f31db6cf4a784c6af148bac846",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-nio.git",
    )

    # version: 1.15.0
    swift_package(
        name = "swiftpkg_swift_nio_extras",
        commit = "91dd2d61fb772e1311bb5f13b59266b579d77e42",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-nio-extras.git",
    )

    # version: 1.23.1
    swift_package(
        name = "swiftpkg_swift_nio_http2",
        commit = "d6656967f33ed8b368b38e4b198631fc7c484a40",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-nio-http2.git",
    )

    # version: 2.23.0
    swift_package(
        name = "swiftpkg_swift_nio_ssl",
        commit = "4fb7ead803e38949eb1d6fabb849206a72c580f3",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-nio-ssl.git",
    )

    # version: 1.15.0
    swift_package(
        name = "swiftpkg_swift_nio_transport_services",
        commit = "c0d9a144cfaec8d3d596aadde3039286a266c15c",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-nio-transport-services.git",
    )

    # version: 1.0.2
    swift_package(
        name = "swiftpkg_swift_numerics",
        commit = "0a5bc04095a675662cf24757cc0640aa2204253b",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-numerics",
    )

    # version: 4.67.5
    swift_package(
        name = "swiftpkg_vapor",
        commit = "eb2da0d749e185789970c32f7fd9c114a339fa13",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/vapor.git",
    )

    # version: 2.6.1
    swift_package(
        name = "swiftpkg_websocket_kit",
        commit = "2d9d2188a08eef4a869d368daab21b3c08510991",
        module_index = "@//:module_index.json",
        remote = "https://github.com/vapor/websocket-kit.git",
    )
