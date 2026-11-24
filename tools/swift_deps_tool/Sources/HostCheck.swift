/// Verifies that SwiftPM on this host can resolve packages for the requested target OS.
public enum HostCheck {
  private static let appleTargets: Set<String> = ["macos", "ios", "tvos", "watchos", "visionos"]

  /// - Parameters:
  ///   - targetOS: The slice's target OS (for example, `macos` or `linux`).
  ///   - hostOS: The OS this tool runs on: `macos` or `linux`.
  public static func check(targetOS: String, hostOS: String) throws {
    let requiredHost: String
    if targetOS == "linux" {
      requiredHost = "linux"
    } else if appleTargets.contains(targetOS) {
      requiredHost = "macos"
    } else {
      throw ToolError(
        message: "unsupported target OS '\(targetOS)' on host '\(hostOS)'")
    }
    guard hostOS == requiredHost else {
      throw ToolError(
        message: "target OS '\(targetOS)' requires a \(requiredHost) host, "
          + "but this host is '\(hostOS)'")
    }
  }
}
