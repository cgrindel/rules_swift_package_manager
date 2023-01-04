# iOS Simulator / Multiplatform Build Example for `swift_bazel`

This example demonstrates that `swift_bazel` can handle the building of components for multiple
platforms. Specifically, this example builds a `Foo` module which is then tested using a
[ios_unit_test](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_unit_test).
When this example is tested, the `Foo` module is built for the host platform and the compatible 
iPhoneSimulator platform.
