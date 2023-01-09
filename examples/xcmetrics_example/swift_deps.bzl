load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 1.13.1
    swift_package(
        name = "swiftpkg_async_http_client",
        commit = "5bee16a79922e3efcb5cea06ecd27e6f8048b56b",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/swift-server/async-http-client.git",
    )

    # version: 1.15.0
    swift_package(
        name = "swiftpkg_async_kit",
        commit = "929808e51fea04f01de0e911ce826ef70c4db4ea",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/async-kit.git",
    )

    # version: 4.5.0
    swift_package(
        name = "swiftpkg_console_kit",
        commit = "a7e67a1719933318b5ab7eaaed355cde020465b1",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/console-kit.git",
    )

    # version: 1.3.3
    swift_package(
        name = "swiftpkg_cryptoswift",
        commit = "e2bc81be54d71d566a52ca17c3983d141c30aa70",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/krzyzanowskim/CryptoSwift.git",
    )

    # version: 4.6.0
    swift_package(
        name = "swiftpkg_fluent",
        commit = "2da106f46b093885f77fa03e3c719ab5bb8cfab4",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/fluent.git",
    )

    # version: 1.36.1
    swift_package(
        name = "swiftpkg_fluent_kit",
        commit = "be7912ee4991bcc8a5390fac0424d1d08221dcc6",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/fluent-kit.git",
    )

    # version: 2.5.0
    swift_package(
        name = "swiftpkg_fluent_postgres_driver",
        commit = "4808c539f08306ae6002f6106813a9350baa141b",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/fluent-postgres-driver.git",
    )

    # version: 1.0.0-rc.9
    swift_package(
        name = "swiftpkg_google_cloud_kit",
        commit = "17b2eec3df26c6535a90b5650dee53670494f4d9",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor-community/google-cloud-kit.git",
    )

    # version: 1.0.0-alpha.9
    swift_package(
        name = "swiftpkg_grpc_swift",
        commit = "be70633c91d722496e5fcb225f822edbd5c36a5a",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/grpc/grpc-swift.git",
    )

    # version: 5.2.0
    swift_package(
        name = "swiftpkg_gzipswift",
        commit = "7a7f17761c76a932662ab77028a4329f67d645a4",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/1024jp/GzipSwift",
    )

    # version: 1.1.1
    swift_package(
        name = "swiftpkg_hypertextapplicationlanguage",
        commit = "aa2c9141d491682f17b2310aed17b9adfc006256",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/swift-aws/HypertextApplicationLanguage.git",
    )

    # version: 4.7.0
    swift_package(
        name = "swiftpkg_jwt_kit",
        commit = "87ce13a1df913ba4d51cf00606df7ef24d455571",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/jwt-kit.git",
    )

    # version: 0.3.0
    swift_package(
        name = "swiftpkg_mobius.swift",
        commit = "afe23c2a66ea1fd52fb9fe76fa051d9a7b789845",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/Spotify/Mobius.swift",
    )

    # version: 4.5.2
    swift_package(
        name = "swiftpkg_multipart_kit",
        commit = "0d55c35e788451ee27222783c7d363cb88092fab",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/multipart-kit.git",
    )

    # version: 8.1.2
    swift_package(
        name = "swiftpkg_nimble",
        commit = "7a46a5fc86cb917f69e3daf79fcb045283d8f008",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/Quick/Nimble",
    )

    # version: 1.0.1
    swift_package(
        name = "swiftpkg_pathkit",
        commit = "3bfd2737b700b9a36565a8c94f4ad2b050a5e574",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/kylef/PathKit.git",
    )

    # version: 3.0.3
    swift_package(
        name = "swiftpkg_perfect_iniparser",
        commit = "42de0efc7a01105e19b80d533d3d282a98277f6c",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/swift-aws/Perfect-INIParser.git",
    )

    # version: 2.9.0
    swift_package(
        name = "swiftpkg_postgres_kit",
        commit = "1174d9bc57798aba7a99451e5380c0eb0fb796d8",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/postgres-kit.git",
    )

    # version: 1.12.1
    swift_package(
        name = "swiftpkg_postgres_nio",
        commit = "7daf026e145de2c07d6e37f4171b1acb4b5f22b1",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/postgres-nio.git",
    )

    # version: 1.11.1
    swift_package(
        name = "swiftpkg_queues",
        commit = "c95c891c3c04817eac1165587fb02457c749523a",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/queues.git",
    )

    # version: 1.0.3
    swift_package(
        name = "swiftpkg_queues_redis_driver",
        commit = "2728477b50e24be82f5bc0bd0722c35656e1c5b1",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/queues-redis-driver.git",
    )

    # version: 2.2.1
    swift_package(
        name = "swiftpkg_quick",
        commit = "09b3becb37cb2163919a3842a4c5fa6ec7130792",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/Quick/Quick",
    )

    # version: 4.6.0
    swift_package(
        name = "swiftpkg_redis",
        commit = "e955843b08064071f465a6b1ca9e04bebad8623a",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/redis.git",
    )

    # version: 1.3.0
    swift_package(
        name = "swiftpkg_redistack",
        commit = "5458d6476e05d5f1b43097f1bc9b599e936b5f2f",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://gitlab.com/mordil/RediStack.git",
    )

    # version: 4.6.0
    swift_package(
        name = "swiftpkg_routing_kit",
        commit = "ffac7b3a127ce1e85fb232f1a6271164628809ad",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/routing-kit.git",
    )

    # version: 4.9.0
    swift_package(
        name = "swiftpkg_soto",
        commit = "b402b8a434ca39f24d189289ab93fbee96664502",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/soto-project/soto.git",
    )

    # version: 4.7.2
    swift_package(
        name = "swiftpkg_soto_core",
        commit = "856a7df0c15763de4f9f3e3d7baea4a8aa009d22",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/soto-project/soto-core.git",
    )

    # version: 0.10.1
    swift_package(
        name = "swiftpkg_spectre",
        commit = "26cc5e9ae0947092c7139ef7ba612e34646086c7",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/kylef/Spectre.git",
    )

    # version: 3.23.0
    swift_package(
        name = "swiftpkg_sql_kit",
        commit = "dcf10a00d7d5df987b7948e6fd5596fb65f6d0c2",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/sql-kit.git",
    )

    # version: 1.0.0
    swift_package(
        name = "swiftpkg_swift_algorithms",
        commit = "b14b7f4c528c942f121c8b860b9410b2bf57825e",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-algorithms.git",
    )

    # version: 1.2.0
    swift_package(
        name = "swiftpkg_swift_argument_parser",
        commit = "fddd1c00396eed152c45a46bea9f47b98e59301d",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-argument-parser",
    )

    # version: 1.0.3
    swift_package(
        name = "swiftpkg_swift_atomics",
        commit = "ff3d2212b6b093db7f177d0855adbc4ef9c5f036",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-atomics.git",
    )

    # version: 1.3.3
    swift_package(
        name = "swiftpkg_swift_backtrace",
        commit = "f25620d5d05e2f1ba27154b40cafea2b67566956",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/swift-server/swift-backtrace.git",
    )

    # version: 1.0.4
    swift_package(
        name = "swiftpkg_swift_collections",
        commit = "937e904258d22af6e447a0b72c0bc67583ef64a2",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-collections.git",
    )

    # version: 2.2.3
    swift_package(
        name = "swiftpkg_swift_crypto",
        commit = "9cc89f0170308b813af05dadcd26f9a2dee47713",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-crypto.git",
    )

    # version: 1.4.4
    swift_package(
        name = "swiftpkg_swift_log",
        commit = "6fe203dc33195667ce1759bf0182975e4653ba1c",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-log",
    )

    # version: 2.3.3
    swift_package(
        name = "swiftpkg_swift_metrics",
        commit = "9b39d811a83cf18b79d7d5513b06f8b290198b10",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-metrics.git",
    )

    # version: 2.46.0
    swift_package(
        name = "swiftpkg_swift_nio",
        commit = "7e3b50b38e4e66f31db6cf4a784c6af148bac846",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-nio.git",
    )

    # version: 1.15.0
    swift_package(
        name = "swiftpkg_swift_nio_extras",
        commit = "91dd2d61fb772e1311bb5f13b59266b579d77e42",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-nio-extras.git",
    )

    # version: 1.23.1
    swift_package(
        name = "swiftpkg_swift_nio_http2",
        commit = "d6656967f33ed8b368b38e4b198631fc7c484a40",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-nio-http2.git",
    )

    # version: 2.23.0
    swift_package(
        name = "swiftpkg_swift_nio_ssl",
        commit = "4fb7ead803e38949eb1d6fabb849206a72c580f3",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-nio-ssl.git",
    )

    # version: 1.15.0
    swift_package(
        name = "swiftpkg_swift_nio_transport_services",
        commit = "c0d9a144cfaec8d3d596aadde3039286a266c15c",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-nio-transport-services.git",
    )

    # version: 1.0.2
    swift_package(
        name = "swiftpkg_swift_numerics",
        commit = "0a5bc04095a675662cf24757cc0640aa2204253b",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-numerics",
    )

    # version: 1.20.3
    swift_package(
        name = "swiftpkg_swift_protobuf",
        commit = "ab3a58b7209a17d781c0d1dbb3e1ff3da306bae8",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-protobuf.git",
    )

    # version: 4.68.0
    swift_package(
        name = "swiftpkg_vapor",
        commit = "888c8b68642c1d340b6b3e9b2b8445fb0f6148c9",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/vapor.git",
    )

    # version: 2.6.1
    swift_package(
        name = "swiftpkg_websocket_kit",
        commit = "2d9d2188a08eef4a869d368daab21b3c08510991",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/vapor/websocket-kit.git",
    )

    # version: 0.2.36
    swift_package(
        name = "swiftpkg_xclogparser",
        commit = "1abc5b96080da8f678b77d11c0a93cdcb614642b",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/MobileNativeFoundation/XCLogParser",
    )

    # version: 0.0.11
    swift_package(
        name = "swiftpkg_xcmetrics",
        commit = "80897ba24c65172f3c56e5e1bb2407205944145b",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/spotify/XCMetrics",
    )

    # version: 3.0.1
    swift_package(
        name = "swiftpkg_yams",
        commit = "81a65c4069c28011ee432f2858ba0de49b086677",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/jpsim/Yams.git",
    )
