load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 0.20200225.4
    swift_package(
        name = "swiftpkg_abseil_cpp_swiftpm",
        commit = "583de9bd60f66b40e78d08599cc92036c2e7e4e1",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/firebase/abseil-cpp-SwiftPM.git",
    )

    # version: 0.7.2
    swift_package(
        name = "swiftpkg_boringssl_swiftpm",
        commit = "dd3eda2b05a3f459fc3073695ad1b28659066eab",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/firebase/boringssl-SwiftPM.git",
    )

    # version: 8.9.1
    swift_package(
        name = "swiftpkg_firebase_ios_sdk",
        commit = "f567ed9a2b30e29159df258049a9c662c517688e",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/firebase/firebase-ios-sdk",
    )

    # version: 8.9.1
    swift_package(
        name = "swiftpkg_googleappmeasurement",
        commit = "9a09ece724128e8d1e14c5133b87c0e236844ac0",
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

    # version: 1.44.3-grpc
    swift_package(
        name = "swiftpkg_grpc_ios",
        commit = "8440b914756e0d26d4f4d054a1c1581daedfc5b6",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/grpc/grpc-ios.git",
    )

    # version: 1.7.2
    swift_package(
        name = "swiftpkg_gtm_session_fetcher",
        commit = "96d7cc73a71ce950723aa3c50ce4fb275ae180b8",
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
        commit = "819d0a2173aff699fb8c364b6fb906f7cdb1a692",
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
