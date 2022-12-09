# Design for Swift Bazel


## Generated Code from Swift Package Manifest

### Swit Package Target

- Generate a BUILD file in the target path directory.
- Executable targets will have a `swift_binary` declaration. 

### Swift Package Product

- All Bazel declarations for Swift package products will be defined in the Swift package path
  directory.
- Each library and executable product will be an `alias` to the corresponding Swift target declaration.
