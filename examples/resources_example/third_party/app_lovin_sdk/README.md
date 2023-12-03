NOTE: This is a vendored verision of https://github.com/AppLovin/AppLovin-MAX-Swift-Package.
Unfortunatley, the code in the repository had [a bug in an
init](https://github.com/AppLovin/AppLovin-MAX-Swift-Package/blob/ef3d2fd34380552067c834afad3c8b732e62569b/Sources/AppLovinSDKResources/ALResourceManager.m#L22)
that prevented us from depending upon it directly. This vendored code has applied a fix.

===

# AppLovin MAX iOS SDK

AppLovin MAX iOS SDK for Swift Package Manager.

## Installation

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for managing the distribution of Swift code. It’s integrated with the Swift build system to automate the process of downloading, compiling, and linking dependencies.

To integrate the AppLovin MAX SDK into your Xcode project using Swift Package Manager:

1. Add it to the `dependencies` of your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git", .upToNextMajor(from: "10.3.6"))
]
```

2. Enable the `-ObjC` flag in Xcode: click on your project settings, go to **Build Settings**, search for **Other Linker Flags** and add `-ObjC`.

Check out our integration [docs](https://dash.applovin.com/documentation/mediation/ios/getting-started/integration) for more info on getting started with the AppLovin MAX SDK.

Note, this Swift package only includes the main AppLovin MAX SDK. We currently do not support installing MAX mediation network adapters using Swift Package Manager.
