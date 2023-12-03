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
