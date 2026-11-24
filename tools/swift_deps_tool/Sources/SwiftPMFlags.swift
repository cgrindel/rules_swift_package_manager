import Foundation

/// The `configure_swift_package` flags for one slice, validated and rendered for SwiftPM.
///
/// The SwiftPM spellings match `swiftpkg/internal/swift_package_lib.sh`.
public struct SwiftPMFlags: Equatable {
  private static let pathKeys: Set<String> = [
    "cache_path", "config_path", "security_path", "netrc", "registries",
  ]
  private static let boolKeys: Set<String> = [
    "dependency_caching", "manifest_caching", "replace_scm_with_registry",
    "use_registry_identity_for_scm",
  ]
  private static let manifestCacheValues = ["shared", "local", "none"]

  /// The keys the client set, exactly as given.
  private let given: [String: String]
  private let workspace: URL

  /// Validates `keyValues` (the `--flag KEY=VALUE` pairs). Rejects unknown keys (including
  /// `build_path`), absolute path values, and malformed booleans or `manifest_cache` values.
  public init(keyValues: [String: String], workspace: URL) throws {
    for (key, value) in keyValues {
      if Self.pathKeys.contains(key) {
        guard !value.hasPrefix("/") else {
          throw ToolError(
            message: "configure_swift_package.\(key) must be workspace-relative, got '\(value)'")
        }
      } else if Self.boolKeys.contains(key) {
        guard value == "true" || value == "false" else {
          throw ToolError(
            message: "configure_swift_package.\(key) must be true or false, got '\(value)'")
        }
      } else if key == "manifest_cache" {
        guard Self.manifestCacheValues.contains(value) else {
          throw ToolError(
            message: "configure_swift_package.\(key) must be one of "
              + "\(Self.manifestCacheValues.joined(separator: ", ")), got '\(value)'")
        }
      } else {
        throw ToolError(message: "unknown configure_swift_package flag '\(key)'")
      }
    }
    self.given = keyValues
    self.workspace = workspace
  }

  /// `--scratch-path <sliceDir>/.build` followed by the SwiftPM flags, sorted by key.
  public func arguments(sliceDir: URL) -> [String] {
    arguments(scratchPath: sliceDir.appendingPathComponent(".build"))
  }

  /// The given keys as `key=value\n` lines sorted by key. Defaults are not printed, so the
  /// result reflects the client's tag.
  public func normalized() -> String {
    given.keys.sorted().map { "\($0)=\(given[$0]!)\n" }.joined()
  }

  func arguments(scratchPath: URL) -> [String] {
    var args = ["--scratch-path", scratchPath.path]
    args += ["--cache-path", cachePath.path]
    args += ["--config-path", configPath.path]
    args.append(
      bool("dependency_caching", true)
        ? "--enable-dependency-cache" : "--disable-dependency-cache")
    args += ["--manifest-cache", given["manifest_cache"] ?? "shared"]
    args.append(
      bool("manifest_caching", true)
        ? "--enable-build-manifest-caching" : "--disable-build-manifest-caching")
    if let netrc = path("netrc") {
      args += ["--netrc-file", netrc.path]
    }
    if bool("replace_scm_with_registry", false) {
      args.append("--replace-scm-with-registry")
    }
    args += ["--security-path", securityPath.path]
    if bool("use_registry_identity_for_scm", false) {
      args.append("--use-registry-identity-for-scm")
    }
    return args
  }

  var cachePath: URL { path("cache_path") ?? workspace.appendingPathComponent(".cache") }
  var configPath: URL { path("config_path") ?? workspace.appendingPathComponent(".config") }
  var securityPath: URL { path("security_path") ?? workspace.appendingPathComponent(".security") }
  /// The client's `registries.json`, if one is configured.
  var registries: URL? { path("registries") }

  private func path(_ key: String) -> URL? {
    given[key].map { workspace.appendingPathComponent($0) }
  }

  private func bool(_ key: String, _ defaultValue: Bool) -> Bool {
    given[key].map { $0 == "true" } ?? defaultValue
  }
}
