import Foundation

/// Removes cache directories of packages that are no longer dependencies.
public enum Prune {
  /// Removes every directory directly under `cacheDir` whose name is not `_main` or in `keep`.
  /// Returns the removed names, sorted.
  public static func removeVanished(cacheDir: URL, keep: Set<String>) throws -> [String] {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: cacheDir.path) else { return [] }
    let keep = keep.union(["_main"])
    var removed: [String] = []
    for name in try fileManager.contentsOfDirectory(atPath: cacheDir.path).sorted() {
      var isDirectory: ObjCBool = false
      let url = cacheDir.appendingPathComponent(name)
      guard !keep.contains(name),
        fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      else { continue }
      try fileManager.removeItem(at: url)
      removed.append(name)
    }
    return removed
  }
}
