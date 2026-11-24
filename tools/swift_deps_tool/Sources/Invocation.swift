import Foundation

public enum Command: String {
  case resolve, update, cache
}

/// The parsed command line of `swift_deps_tool`.
public struct Invocation: Equatable {
  public var command: Command
  public var workspace: URL
  public var swiftTool: URL
  public var targetOS: String
  public var packagePath: String
  public var sliceDir: String
  public var slicePackage: String
  public var swiftLabel: String
  public var config: String
  public var flags: [String: String]
  public var patches: [String: [String]]
  public var patchArgs: [String: [String]]

  /// Parses `args` (without argv[0]). The first argument is the command.
  ///
  /// `--workspace` defaults to `BUILD_WORKSPACE_DIRECTORY`. `--swift-tool` defaults to the
  /// runfiles location of `RSPM_SWIFT_TOOL`.
  public static func parse(_ args: [String], env: [String: String]) throws -> Invocation {
    let commandNames = "resolve, update, cache"
    guard let first = args.first else {
      throw ToolError(message: "missing command; expected one of: \(commandNames)")
    }
    guard let command = Command(rawValue: first) else {
      throw ToolError(message: "unknown command '\(first)'; expected one of: \(commandNames)")
    }

    var single: [String: String] = [:]
    var flags: [String: String] = [:]
    var patches: [String: [String]] = [:]
    var patchArgs: [String: [String]] = [:]
    let singleFlags: Set<String> = [
      "--workspace", "--swift-tool", "--target-os", "--package", "--slice", "--slice-package",
      "--swift-label", "--config",
    ]

    var index = 1
    while index < args.count {
      let flag = args[index]
      let isRepeatable = ["--flag", "--patch", "--patch-args"].contains(flag)
      guard singleFlags.contains(flag) || isRepeatable else {
        throw ToolError(message: "unknown flag '\(flag)'")
      }
      guard index + 1 < args.count else {
        throw ToolError(message: "missing value for \(flag)")
      }
      let value = args[index + 1]
      index += 2

      if !isRepeatable {
        single[flag] = value
        continue
      }
      let (key, keyValue) = try splitKeyValue(value, flag: flag)
      switch flag {
      case "--flag": flags[key] = keyValue
      case "--patch": patches[key, default: []].append(keyValue)
      default: patchArgs[key, default: []].append(keyValue)
      }
    }

    func required(_ flag: String) throws -> String {
      guard let value = single[flag], !value.isEmpty else {
        throw ToolError(message: "missing required flag \(flag)")
      }
      return value
    }

    if single["--workspace"] == nil {
      single["--workspace"] = env["BUILD_WORKSPACE_DIRECTORY"]
    }
    if single["--swift-tool"] == nil, let rlocationpath = env["RSPM_SWIFT_TOOL"],
      !rlocationpath.isEmpty
    {
      single["--swift-tool"] = Runfiles.resolve(
        rlocationpath: rlocationpath, env: env, argv0: CommandLine.arguments[0],
        cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      ).path
    }

    return Invocation(
      command: command,
      workspace: URL(fileURLWithPath: try required("--workspace")),
      swiftTool: URL(fileURLWithPath: try required("--swift-tool")),
      targetOS: try required("--target-os"),
      packagePath: try required("--package"),
      sliceDir: try required("--slice"),
      slicePackage: try required("--slice-package"),
      swiftLabel: try required("--swift-label"),
      config: try required("--config"),
      flags: flags,
      patches: patches,
      patchArgs: patchArgs
    )
  }

  /// Splits `KEY=VALUE` on the first `=`.
  private static func splitKeyValue(_ value: String, flag: String) throws -> (String, String) {
    guard let separator = value.firstIndex(of: "="), separator != value.startIndex else {
      throw ToolError(message: "\(flag) expects KEY=VALUE, got '\(value)'")
    }
    return (
      String(value[..<separator]), String(value[value.index(after: separator)...])
    )
  }
}
