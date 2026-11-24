import Foundation

/// The parts of `swift package describe --type json` output that the tool reads.
public struct Desc {
  /// The package's `name`, lower-cased.
  public var identity: String
  /// `dependencies[].path` for `fileSystem` dependencies, in file order, as written.
  public var fileSystemDependencyPaths: [String]

  public init(data: Data) throws {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let name = object["name"] as? String
    else {
      throw ToolError(message: "package description has no top-level name")
    }
    identity = name.lowercased()
    let dependencies = object["dependencies"] as? [[String: Any]] ?? []
    fileSystemDependencyPaths = dependencies.compactMap { dependency in
      guard dependency["type"] as? String == "fileSystem" else { return nil }
      return dependency["path"] as? String
    }
  }
}
