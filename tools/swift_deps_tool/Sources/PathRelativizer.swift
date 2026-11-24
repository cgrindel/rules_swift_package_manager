import Foundation

/// Rewrites absolute paths in SwiftPM JSON output so the cache holds no machine-specific paths.
public enum PathRelativizer {
  /// Two textual passes over `json`:
  /// 1. `<packageRoot>/` becomes `./` and `<packageRoot>"` becomes `./"`. The trailing `/` or `"`
  ///    keeps `/w/pkg` from matching `/w/pkgOther`. Mirrors `_replace_working_directory` in
  ///    `swiftpkg/internal/repository_utils.bzl`.
  /// 2. Every remaining string value that is `<workspaceRoot>` or starts with `<workspaceRoot>/`
  ///    becomes the path from `packageRoot` to it, with `..` segments (for example
  ///    `../MyAmazingModule` for a sibling package).
  ///
  /// Paths outside the workspace stay absolute; `absolutePaths(in:)` lists them. Both roots must
  /// already have their symlinks resolved, since SwiftPM prints resolved paths.
  public static func relativize(_ json: Data, packageRoot: URL, workspaceRoot: URL) -> Data {
    let root = packageRoot.path
    var text = String(decoding: json, as: UTF8.self)
      .replacingOccurrences(of: root + "/", with: "./", options: .literal)
      .replacingOccurrences(of: root + "\"", with: "./\"", options: .literal)
    let workspace = workspaceRoot.path
    for value in stringValues(in: text, startingWith: "\"" + workspace)
    where value == workspace || value.hasPrefix(workspace + "/") {
      text = text.replacingOccurrences(
        of: "\"\(value)\"", with: "\"\(relativePath(from: root, to: value))\"",
        options: .literal)
    }
    return Data(text.utf8)
  }

  /// The distinct string values in `json` that are absolute paths, sorted.
  public static func absolutePaths(in json: Data) -> [String] {
    stringValues(in: String(decoding: json, as: UTF8.self), startingWith: "\"/")
  }

  /// The distinct, sorted string values that begin with `prefix` (which starts with `"`).
  private static func stringValues(in text: String, startingWith prefix: String) -> [String] {
    var values: Set<String> = []
    var searchStart = text.startIndex
    while let match = text.range(of: prefix, options: .literal, range: searchStart..<text.endIndex)
    {
      let valueStart = text.index(after: match.lowerBound)
      guard let end = text.range(of: "\"", options: .literal, range: valueStart..<text.endIndex)
      else { break }
      values.insert(String(text[valueStart..<end.lowerBound]))
      searchStart = end.upperBound
    }
    return values.sorted()
  }

  /// The path from directory `base` to `target`, both absolute and standardized.
  private static func relativePath(from base: String, to target: String) -> String {
    let baseParts = base.split(separator: "/")
    let targetParts = target.split(separator: "/")
    var common = 0
    while common < baseParts.count, common < targetParts.count,
      baseParts[common] == targetParts[common]
    {
      common += 1
    }
    let parts =
      Array(repeating: "..", count: baseParts.count - common)
      + targetParts[common...].map(String.init)
    return parts.isEmpty ? "." : parts.joined(separator: "/")
  }
}
