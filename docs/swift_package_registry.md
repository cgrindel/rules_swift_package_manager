# Using a Swift package registry

A [Swift package registry](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/PackageRegistryUsage.md) is a new mechanism in SPM which allows fetching packages from a remote registry service. This allows users and companies to host their own registries with their own mirrored or private packages.

Note that Swift package registries are still fairly new and there may be bugs or unknown issues, if you encounter any, please file an issue here or with the Swift Package Manager project.

## Using a Swift package registry with rules_swift_package_manager

**rules_swift_package_manager** supports Swift package registries via the `registry_swift_package` rule which can be used to declare packages that are hosted on a Swift package registry.

### 1. Create a `registries.json` file

To setup the registry you will first need to create a `registries.json` file which tells the Swift Package Manager where to find registry declared packages.

To do this, you can use the `swift package-registry` commands to setup the registry:

```sh
swift package-registry set <registry_url>
```

This will create a `.swiftpm` directory which will contain a `.swiftpm/configuration/registries.json` file. With this file you can decide to keep it in the location output by the command (required if using `swift package` commands directly) or move it to a preferred location when using the `@swift_package` repository.

### 2. Declare the use of the registry in your `MODULE.bazel` file

To use the registry you will need to declare the use of the registry in your `MODULE.bazel` file, in the `swift_deps` extension.

For example, if the `registries.json` file was located next to the `MODULE.bazel` file, you could declare the use of the registry as follows:

```starlark
swift_deps.from_package(
    registries = "//:registries.json",
    resolved = "//:Package.resolved",
    swift = "//:Package.swift",
)
```

### 3. (Optional) Consider using `replace_scm_with_registry` option

When using a registry you typically want to ensure all packages (even those declared in transitive dependencies) are fetched from the registry. To do this you can use the `--replace-scm-with-registry` option in `swift package` commands.

If using `swift package` directly, you just need to ensure the option is passed whenever you run a `swift package update` or `swift package resolve` command. This will replace packages declared as source control dependencies with their registry equivalents (if found in the registry).

The result of this is a `Package.resolved` file which contains all registry pins.

If using `@swift_package` repository, you set the `replace_scm_with_registry` option in the `swift_deps` extension.

```starlark
swift_deps.configure_swift_package(
    replace_scm_with_registry = True,
)
```

This ensures that when running something like `@swift_package//:resolve` the `Package.resolved` file will contain all registry pins.

## More information

For more information on using Swift package registries with the Swift Package Manager, please see the [Swift Package Manager registry usage documentation](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/PackageRegistryUsage.md), the [Swift Package Manager registry specification](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/Registry.md), and our [Swift Package Manager registry example](/examples/swift_package_registry_example/MODULE.bazel).
