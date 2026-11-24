import Foundation

/// The entry point of `swift_deps_tool`: parse, check the host, dispatch.
public enum CLI {
  /// Runs the tool and returns its exit code. `arguments` includes argv[0].
  public static func main(_ arguments: [String]) -> Int32 {
    do {
      let invocation = try Invocation.parse(
        Array(arguments.dropFirst()), env: ProcessInfo.processInfo.environment)
      try HostCheck.check(targetOS: invocation.targetOS, hostOS: hostOS)
      try run(invocation)
      return 0
    } catch {
      FileHandle.standardError.write(Data("\(error)\n".utf8))
      return 1
    }
  }

  private static var hostOS: String {
    #if os(macOS)
      return "macos"
    #elseif os(Linux)
      return "linux"
    #else
      return "unsupported"
    #endif
  }

  private static func run(_ invocation: Invocation) throws {
    try CacheStep(invocation).run()
  }
}
