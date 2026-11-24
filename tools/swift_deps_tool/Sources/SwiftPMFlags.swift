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
  /// `build_path`), empty or absolute path values, and malformed booleans or `manifest_cache`
  /// values.
  public init(keyValues: [String: String], workspace: URL) throws {
    for (key, value) in keyValues {
      if Self.pathKeys.contains(key) {
        // An empty path would resolve to the workspace root.
        guard !value.isEmpty else {
          throw ToolError(message: "configure_swift_package.\(key) must not be empty")
        }
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
    arguments(sliceDir: sliceDir, scratchPath: sliceDir.appendingPathComponent(".build"))
  }

  /// The flags as text, for staleness checks. A Starlark twin must produce the same bytes:
  ///
  /// - one `key=value\n` line per pair passed in, and no others (defaults are not added);
  /// - lines sorted by key in ASCII order;
  /// - each value verbatim, so booleans are spelled `true` or `false`;
  /// - an empty map gives the empty string.
  public func normalized() -> String {
    given.keys.sorted().map { "\($0)=\(given[$0]!)\n" }.joined()
  }

  /// `scratchPath` may differ from `<sliceDir>/.build` (a dependency's copy has its own), but the
  /// default cache, config and security directories always stay under `<sliceDir>/.build`.
  func arguments(sliceDir: URL, scratchPath: URL) -> [String] {
    var args = ["--scratch-path", scratchPath.path]
    args += ["--cache-path", cachePath(sliceDir: sliceDir).path]
    args += ["--config-path", configPath(sliceDir: sliceDir).path]
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
    args += ["--security-path", securityPath(sliceDir: sliceDir).path]
    if bool("use_registry_identity_for_scm", false) {
      args.append("--use-registry-identity-for-scm")
    }
    return args
  }

  /// A given path resolves against the workspace; the default is `<sliceDir>/.build/<name>`,
  /// which `init` already lists in `.bazelignore` and `.gitignore`.
  func cachePath(sliceDir: URL) -> URL { path("cache_path", default: ".cache", sliceDir) }
  func configPath(sliceDir: URL) -> URL { path("config_path", default: ".config", sliceDir) }
  func securityPath(sliceDir: URL) -> URL {
    path("security_path", default: ".security", sliceDir)
  }
  /// The client's `registries.json`, if one is configured.
  var registries: URL? { path("registries") }

  private func path(_ key: String, default name: String, _ sliceDir: URL) -> URL {
    path(key) ?? sliceDir.appendingPathComponent(".build").appendingPathComponent(name)
  }

  private func path(_ key: String) -> URL? {
    given[key].map { workspace.appendingPathComponent($0) }
  }

  private func bool(_ key: String, _ defaultValue: Bool) -> Bool {
    given[key].map { $0 == "true" } ?? defaultValue
  }
}
