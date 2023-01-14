load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 0.20200225.4
    swift_package(
        name = "swiftpkg_abseil_cpp_swiftpm",
        commit = "fffc3c2729be5747390ad02d5100291a0d9ad26a",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/firebase/abseil-cpp-SwiftPM.git",
    )

    # version: 0.7.2
    swift_package(
        name = "swiftpkg_boringssl_swiftpm",
        commit = "734a8247442fde37df4364c21f6a0085b6a36728",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/firebase/boringssl-SwiftPM.git",
    )

    # version: 8.9.1
    swift_package(
        name = "swiftpkg_firebase_ios_sdk",
        commit = "839cc6b0cd80b0b8bf81fe9bd82b743b25dc6446",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/firebase/firebase-ios-sdk",
    )

    # version: 8.9.1
    swift_package(
        name = "swiftpkg_googleappmeasurement",
        commit = "9b2f6aca5b4685c45f9f5481f19bee8e7982c538",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/google/GoogleAppMeasurement.git",
    )

    # version: 9.2.0
    swift_package(
        name = "swiftpkg_googledatatransport",
        commit = "5056b15c5acbb90cd214fe4d6138bdf5a740e5a8",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/google/GoogleDataTransport.git",
    )

    # version: 7.11.0
    swift_package(
        name = "swiftpkg_googleutilities",
        commit = "0543562f85620b5b7c510c6bcbef75b562a5127b",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/google/GoogleUtilities.git",
    )

    # version: 1.28.4
    swift_package(
        name = "swiftpkg_grpc_swiftpm",
        commit = "fb405dd2c7901485f7e158b24e3a0a47e4efd8b5",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/firebase/grpc-SwiftPM.git",
    )

    # version: 1.7.2
    swift_package(
        name = "swiftpkg_gtm_session_fetcher",
        commit = "4e9bbf2808b8fee444e84a48f5f3c12641987d3e",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/google/gtm-session-fetcher.git",
    )

    # version: 1.22.2
    swift_package(
        name = "swiftpkg_leveldb",
        commit = "0706abcc6b0bd9cedfbb015ba840e4a780b5159b",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/firebase/leveldb.git",
    )

    # version: 2.30908.0
    swift_package(
        name = "swiftpkg_nanopb",
        commit = "7ee9ef9f627d85cbe1b8c4f49a3ed26eed216c77",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/firebase/nanopb.git",
    )

    # version: 2.1.1
    swift_package(
        name = "swiftpkg_promises",
        commit = "3e4e743631e86c8c70dbc6efdc7beaa6e90fd3bb",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/google/promises.git",
    )

    # version: 1.20.3
    swift_package(
        name = "swiftpkg_swift_protobuf",
        commit = "ab3a58b7209a17d781c0d1dbb3e1ff3da306bae8",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-protobuf.git",
    )
