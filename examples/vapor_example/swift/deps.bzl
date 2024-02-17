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
        commit = "a7dd7001196d39b758e4990ec0f26f80162f4c84",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/console-kit.git",
    )

    # version: 4.8.0
    swift_package(
        name = "swiftpkg_fluent",
        commit = "a586a5d4164f23a0ee4e02e1f467b9bbef0c9f1c",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/fluent.git",
    )

    # version: 1.44.1
    swift_package(
        name = "swiftpkg_fluent_kit",
        commit = "e0bb2b060249b7a501249b1612807b2eaaec28c6",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/fluent-kit.git",
    )

    # version: 4.5.0
    swift_package(
        name = "swiftpkg_fluent_sqlite_driver",
        commit = "d76674f9ec744c773c4126384abe6e74bea68bab",
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
        commit = "2a92a7eac411a82fb3a03731be5e76773ebe1b3e",
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
        commit = "b4766692f2b3e26e4809aeb9f298c9811fdfe4ed",
        dependencies_index = "@//swift:deps_index.json",
        remote = "https://github.com/vapor/sqlite-kit.git",
    )

    # version: 1.3.0
    swift_package(
        name = "swiftpkg_sqlite_nio",
        commit = "f46b6db58333b1dbff012c9030b8dcd455c2f645",
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
        commit = "702cd7c56d5d44eeba73fdf83918339b26dc855c",
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
        commit = "9c22e4f810ce780453f563fba98e1a1039f83d56",
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
        commit = "9da9d14f43bc1b32b384f0b4eb231b8a5a851dee",
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
