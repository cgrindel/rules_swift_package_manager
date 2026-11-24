import Foundation

/// Locates a file in this binary's runfiles tree.
public enum Runfiles {
  /// Returns the first existing candidate, in this order:
  /// 1. `$RUNFILES_DIR/<rlocationpath>`
  /// 2. `<argv0>.runfiles/<rlocationpath>`
  /// 3. `<parent of cwd>/<rlocationpath>` (`bazel run` starts in `<runfiles>/_main`)
  ///
  /// If none exists, returns candidate 3 so the caller fails with a clear error when it uses it.
  public static func resolve(
    rlocationpath: String, env: [String: String], argv0: String, cwd: URL
  ) -> URL {
    var candidates: [URL] = []
    if let runfilesDir = env["RUNFILES_DIR"], !runfilesDir.isEmpty {
      candidates.append(URL(fileURLWithPath: runfilesDir).appendingPathComponent(rlocationpath))
    }
    candidates.append(
      URL(fileURLWithPath: argv0 + ".runfiles").appendingPathComponent(rlocationpath))
    let fallback = cwd.deletingLastPathComponent().appendingPathComponent(rlocationpath)
    candidates.append(fallback)

    return candidates.first { FileManager.default.fileExists(atPath: $0.path) } ?? fallback
  }

  /// Returns the runfiles root that `resolved` was found under: `resolved` with the
  /// `rlocationpath` components removed.
  public static func root(of resolved: URL, rlocationpath: String) -> URL {
    let depth = rlocationpath.split(separator: "/").count
    var root = resolved
    for _ in 0..<depth {
      root = root.deletingLastPathComponent()
    }
    return root
  }
}
