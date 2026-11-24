/// An error reported to the user. `description` is what the tool prints to stderr.
public struct ToolError: Error, CustomStringConvertible {
  public var slice: String
  public var package: String?
  public var command: String?
  public var message: String

  public init(slice: String = "", package: String? = nil, command: String? = nil, message: String) {
    self.slice = slice
    self.package = package
    self.command = command
    self.message = message
  }

  public var description: String {
    var result = slice.isEmpty ? message : "slice \(slice): \(message)"
    if let package {
      result += " (package \(package))"
    }
    if let command {
      result += " (command: \(command))"
    }
    return result
  }
}
