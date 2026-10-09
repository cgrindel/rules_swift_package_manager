# Resources in External Package

This example demonstrates using an external package that has its resources under a directory. The
generated Bazel build files should ensure that the resources are found and made available in a
resource bundle.

## Notes

### Multiple Swift packages with Objc targets that contain resources

Both the `third_party/app_lovin_sdk` and the `SDWebImageSwiftUI` packages have or use Objective-C
code that have resources. The inclusion of both in this project ensures that the resource bundle
accessors that are generated for these packages work properly.

### C targets with resources

The `third_party/c_package_with_resources` package has a C-only target with a privacy manifest resource, mirroring `firebase/nanopb`. It ensures that clang targets without Objective-C sources still produce a resource bundle that is embedded in the consuming application.
