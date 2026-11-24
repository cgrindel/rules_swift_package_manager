import Foundation

/// Finds the local (`fileSystem`) packages a root package depends on, transitively.
public enum LocalPackages {
  /// Walks `fileSystem` dependencies from `root` until no new package appears. Each package is
  /// read once, so cycles terminate. Returns the packages other than `root`, in discovery order.
  public static func discover(root: URL, readDesc: (URL) throws -> Desc) throws -> [URL] {
    let start = root.standardizedFileURL
    var seen: Set<String> = [key(start)]
    var work = [start]
    var found: [URL] = []
    while !work.isEmpty {
      let package = work.removeFirst()
      for path in try readDesc(package).fileSystemDependencyPaths {
        let dependency = URL(
          fileURLWithPath: path, relativeTo: package.appendingPathComponent("", isDirectory: true)
        ).standardizedFileURL
        guard seen.insert(key(dependency)).inserted else { continue }
        found.append(dependency)
        work.append(dependency)
      }
    }
    return found
  }

  private static func key(_ url: URL) -> String {
    url.standardizedFileURL.resolvingSymlinksInPath().path
  }
}
