import Foundation

/// Writes a package's relativized `dump-package` and `describe` output to its cache directory.
public struct Manifests {
  /// Runs `dump-package` into `cacheDir/dump.json` and `describe --type json` into
  /// `cacheDir/desc.json`, both relativized to the package root, and returns the description.
  public static func write(package: URL, cacheDir: URL, spm: SwiftPM, scratchPath: URL?) throws
    -> Desc
  {
    try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    let root = try realPath(package)
    func dump(_ args: [String], to name: String) throws -> Data {
      let output: Data
      do {
        output = try spm.run(args, in: package, scratchPath: scratchPath)
      } catch var error as ToolError {
        error.package = package.lastPathComponent
        throw error
      }
      let relativized = PathRelativizer.relativize(output, packageRoot: root)
      try relativized.write(to: cacheDir.appendingPathComponent(name), options: .atomic)
      return relativized
    }
    _ = try dump(["dump-package"], to: "dump.json")
    return try Desc(data: dump(["describe", "--type", "json"], to: "desc.json"))
  }

  /// The package directory with every symlink resolved, as SwiftPM prints it. On macOS,
  /// `URL.resolvingSymlinksInPath()` maps `/private/var/...` back to `/var/...`, which would not
  /// match SwiftPM's output, so this uses `realpath(3)`.
  private static func realPath(_ url: URL) throws -> URL {
    guard let resolved = realpath(url.path, nil) else {
      throw ToolError(
        package: url.lastPathComponent, message: "cannot resolve package directory \(url.path)")
    }
    defer { free(resolved) }
    return URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
  }
}
