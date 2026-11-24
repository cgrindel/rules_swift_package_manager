import Foundation

/// Rewrites absolute package-root paths in SwiftPM JSON output to `./`-relative ones.
public enum PathRelativizer {
  /// Replaces `<root>/` with `./` and `<root>"` with `./"` in `json`, leaving all other bytes
  /// alone. The trailing `/` or `"` keeps `/w/pkg` from matching `/w/pkgOther`. Mirrors
  /// `_replace_working_directory` in `swiftpkg/internal/repository_utils.bzl`.
  ///
  /// `packageRoot` must already have its symlinks resolved, since SwiftPM prints resolved paths.
  public static func relativize(_ json: Data, packageRoot: URL) -> Data {
    let root = packageRoot.path
    let text = String(decoding: json, as: UTF8.self)
      .replacingOccurrences(of: root + "/", with: "./")
      .replacingOccurrences(of: root + "\"", with: "./\"")
    return Data(text.utf8)
  }
}
