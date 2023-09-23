load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 1.19.0
    swift_package(
        name = "swiftpkg_async_http_client",
        commit = "16f7e62c08c6969899ce6cc277041e868364e5cf",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/swift-server/async-http-client.git",
    )

    # version: 1.18.0
    swift_package(
        name = "swiftpkg_async_kit",
        commit = "eab9edff78e8ace20bd7cb6e792ab46d54f59ab9",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/async-kit.git",
    )

    # version: 4.5.0
    swift_package(
        name = "swiftpkg_console_kit",
        commit = "a7e67a1719933318b5ab7eaaed355cde020465b1",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/console-kit.git",
    )

    # version: 4.8.0
    swift_package(
        name = "swiftpkg_fluent",
        commit = "4b4d8bf15a06fd60137e9c543e5503c4b842654e",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/fluent.git",
    )

    # version: 1.44.1
    swift_package(
        name = "swiftpkg_fluent_kit",
        commit = "ccea9820fe31076f994f7c1c1d584009cad6bdb2",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/fluent-kit.git",
    )

    # version: 4.5.0
    swift_package(
        name = "swiftpkg_fluent_sqlite_driver",
        commit = "138a546e3b7e33efa5362e05da2a0dec3a30534f",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/fluent-sqlite-driver.git",
    )

    # version: 4.5.2
    swift_package(
        name = "swiftpkg_multipart_kit",
        commit = "0d55c35e788451ee27222783c7d363cb88092fab",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/multipart-kit.git",
    )

    # version: 4.6.0
    swift_package(
        name = "swiftpkg_routing_kit",
        commit = "ffac7b3a127ce1e85fb232f1a6271164628809ad",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/routing-kit.git",
    )

    # version: 3.28.0
    swift_package(
        name = "swiftpkg_sql_kit",
        commit = "b2f128cb62a3abfbb1e3b2893ff3ee69e70f4f0f",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/sql-kit.git",
    )

    # version: 4.3.1
    swift_package(
        name = "swiftpkg_sqlite_kit",
        commit = "2b20fc0f4f6574f59dae402ccf0ed050c6790b43",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/sqlite-kit.git",
    )

    # version: 1.3.0
    swift_package(
        name = "swiftpkg_sqlite_nio",
        commit = "3b93e0a58643cc02a8bc42014fe462e1532df62d",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/sqlite-nio.git",
    )

    # version: 1.0.0
    swift_package(
        name = "swiftpkg_swift_algorithms",
        commit = "b14b7f4c528c942f121c8b860b9410b2bf57825e",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/apple/swift-algorithms.git",
    )

    # version: 1.1.0
    swift_package(
        name = "swiftpkg_swift_atomics",
        commit = "6c89474e62719ddcc1e9614989fff2f68208fe10",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/apple/swift-atomics.git",
    )

    # version: 1.3.3
    swift_package(
        name = "swiftpkg_swift_backtrace",
        commit = "f25620d5d05e2f1ba27154b40cafea2b67566956",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/swift-server/swift-backtrace.git",
    )

    # version: 1.0.4
    swift_package(
        name = "swiftpkg_swift_collections",
        commit = "937e904258d22af6e447a0b72c0bc67583ef64a2",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/apple/swift-collections.git",
    )

    # version: 2.2.4
    swift_package(
        name = "swiftpkg_swift_crypto",
        commit = "75ec60b8b4cc0f085c3ac414f3dca5625fa3588e",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/apple/swift-crypto.git",
    )

    # version: 1.5.3
    swift_package(
        name = "swiftpkg_swift_log",
        commit = "532d8b529501fb73a2455b179e0bbb6d49b652ed",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/apple/swift-log.git",
    )

    # version: 2.3.3
    swift_package(
        name = "swiftpkg_swift_metrics",
        commit = "9b39d811a83cf18b79d7d5513b06f8b290198b10",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/apple/swift-metrics.git",
    )

    # version: 2.58.0
    swift_package(
        name = "swiftpkg_swift_nio",
        commit = "cf281631ff10ec6111f2761052aa81896a83a007",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/apple/swift-nio.git",
    )

    # version: 1.19.0
    swift_package(
        name = "swiftpkg_swift_nio_extras",
        commit = "0e0d0aab665ff1a0659ce75ac003081f2b1c8997",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/apple/swift-nio-extras.git",
    )

    # version: 1.23.1
    swift_package(
        name = "swiftpkg_swift_nio_http2",
        commit = "d6656967f33ed8b368b38e4b198631fc7c484a40",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/apple/swift-nio-http2.git",
    )

    # version: 2.25.0
    swift_package(
        name = "swiftpkg_swift_nio_ssl",
        commit = "320bd978cceb8e88c125dcbb774943a92f6286e9",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/apple/swift-nio-ssl.git",
    )

    # version: 1.19.0
    swift_package(
        name = "swiftpkg_swift_nio_transport_services",
        commit = "e7403c35ca6bb539a7ca353b91cc2d8ec0362d58",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/apple/swift-nio-transport-services.git",
    )

    # version: 1.0.2
    swift_package(
        name = "swiftpkg_swift_numerics",
        commit = "0a5bc04095a675662cf24757cc0640aa2204253b",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/apple/swift-numerics",
    )

    # version: 4.81.0
    swift_package(
        name = "swiftpkg_vapor",
        commit = "1f2b44b1739ff5cdec6c6dfec40020f5d4b2a813",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/vapor.git",
    )

    # version: 2.14.0
    swift_package(
        name = "swiftpkg_websocket_kit",
        commit = "53fe0639a98903858d0196b699720decb42aee7b",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/websocket-kit.git",
    )
