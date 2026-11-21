// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "symlinked_header_example",
    dependencies: [
        // Source/PrivateHeaders/Ably/ARTSRWebSocket.h is a symlink to
        // Source/SocketRocket/ARTSRWebSocket.h.
        .package(url: "https://github.com/ably/ably-cocoa", exact: "1.2.41"),
        // Public headers under include/ are symlinks into the package.
        .package(url: "https://github.com/ably/delta-codec-cocoa", exact: "1.3.5"),
        .package(url: "https://github.com/rvi/msgpack-objective-C", exact: "0.4.0"),
    ]
)
