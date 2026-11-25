// swift-tools-version:5.3

import PackageDescription

// Mirrors the shape of firebase/nanopb: a C-only target with a privacy
// manifest resource and no Objective-C sources.
let package = Package(
    name: "c-package-with-resources",
    products: [
        .library(name: "CLibWithResources", targets: ["CLibWithResources"]),
    ],
    targets: [
        .target(
            name: "CLibWithResources",
            path: ".",
            sources: [
                "c_lib_with_resources.c",
            ],
            resources: [.process("spm_resources/PrivacyInfo.xcprivacy")],
            publicHeadersPath: "spm_headers"
        ),
    ]
)
