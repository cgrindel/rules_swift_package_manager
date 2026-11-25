// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwsSdkExample",
    dependencies: [
        // Capped below 1.7.0. Starting with 1.7.0, every aws-sdk-swift service
        // target declares smithy-swift's `SmithyCodeGeneratorPlugin`, a SwiftPM
        // build tool plugin that generates the per-operation schema code (e.g.
        // `CognitoIdentityClient.getIdOperation`) at build time. This ruleset
        // does not run build tool plugins yet, so those symbols never exist and
        // the generated clients fail to compile. See #46.
        .package(url: "https://github.com/awslabs/aws-sdk-swift", "1.6.113" ..< "1.7.0"),
    ]
)
