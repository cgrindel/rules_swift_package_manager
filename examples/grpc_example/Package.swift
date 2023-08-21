// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "grpc_example",
    dependencies: [
        // NOTE: The https://github.com/grpc/grpc-swift are currently coming from rules_swift.
        // Related Slack thread: https://bazelbuild.slack.com/archives/CD3QY5C2X/p1692055426375909
    ]
)
