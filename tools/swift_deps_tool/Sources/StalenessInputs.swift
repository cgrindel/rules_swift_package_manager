import Foundation

/// Copies every input that influenced SwiftPM into the cache, so the extension can detect a
/// stale cache by comparing files.
public enum StalenessInputs {
  private static let mainDir = "_main"
  private static let cachedSuffix = ".cached"

  /// Writes, under `cacheDir`:
  /// - `_main/Package.swift.cached` and `_main/Package@swift-*.swift.cached`
  /// - `_main/Package.resolved.cached`, `_main/flags.cached`, `_main/swift_version.txt`
  /// - `_main/registries.json.cached` when `registries` is set
  /// - `<identity>/Package.swift.cached` (and variants) for each local package
  /// - `<identity>/patches/<basename>` for each patch file
  ///
  /// Copies are byte-exact. Earlier copies that no longer have a source are removed.
  public static func write(
    cacheDir: URL, packageSwift: URL, sliceResolved: URL,
    locals: [(identity: String, packageSwift: URL)], flags: SwiftPMFlags, registries: URL?,
    patches: [String: [URL]], swiftVersion: String
  ) throws {
    let main = cacheDir.appendingPathComponent(mainDir)
    try copyManifests(packageSwift, to: main)
    try copyOptional(sliceResolved, to: main.appendingPathComponent("Package.resolved.cached"))
    if let registries, !FileManager.default.fileExists(atPath: registries.path) {
      throw ToolError(message: "configured registries file \(registries.path) does not exist")
    }
    try copyOptional(registries, to: main.appendingPathComponent("registries.json.cached"))
    try Data(flags.normalized().utf8).write(
      to: main.appendingPathComponent("flags.cached"), options: .atomic)
    try Data("\(swiftVersion)\n".utf8).write(
      to: main.appendingPathComponent("swift_version.txt"), options: .atomic)
    for local in locals {
      try copyManifests(local.packageSwift, to: cacheDir.appendingPathComponent(local.identity))
    }
    for (identity, files) in patches {
      try copyPatches(files, to: cacheDir.appendingPathComponent(identity), identity: identity)
    }
  }

  /// Copies `Package.swift` and its `Package@swift-*.swift` siblings, replacing earlier copies.
  private static func copyManifests(_ packageSwift: URL, to dir: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    for name in try fileManager.contentsOfDirectory(atPath: dir.path)
    where isManifest(name, suffix: cachedSuffix) {
      try fileManager.removeItem(at: dir.appendingPathComponent(name))
    }
    let packageDir = packageSwift.deletingLastPathComponent()
    let variants = try fileManager.contentsOfDirectory(atPath: packageDir.path)
      .filter { $0 != packageSwift.lastPathComponent && isManifest($0, suffix: "") }
    for name in [packageSwift.lastPathComponent] + variants.sorted() {
      try copy(
        packageDir.appendingPathComponent(name), to: dir.appendingPathComponent(name + cachedSuffix)
      )
    }
  }

  private static func isManifest(_ name: String, suffix: String) -> Bool {
    guard name.hasSuffix(suffix) else { return false }
    let base = name.dropLast(suffix.count)
    return base == "Package.swift"
      || (base.hasPrefix("Package@swift-") && base.hasSuffix(".swift"))
  }

  private static func copyPatches(_ files: [URL], to dir: URL, identity: String) throws {
    let patchesDir = dir.appendingPathComponent("patches")
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: patchesDir.path) {
      try fileManager.removeItem(at: patchesDir)
    }
    guard !files.isEmpty else { return }
    try fileManager.createDirectory(at: patchesDir, withIntermediateDirectories: true)
    var seen: Set<String> = []
    for file in files {
      guard seen.insert(file.lastPathComponent).inserted else {
        throw ToolError(
          package: identity,
          message: "two patches are named \(file.lastPathComponent); patch file names must be "
            + "unique per package")
      }
      try copy(file, to: patchesDir.appendingPathComponent(file.lastPathComponent))
    }
  }

  /// Copies `source` if it is set and exists; otherwise removes an earlier copy.
  private static func copyOptional(_ source: URL?, to destination: URL) throws {
    if let source, FileManager.default.fileExists(atPath: source.path) {
      try copy(source, to: destination)
    } else if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }
  }

  private static func copy(_ source: URL, to destination: URL) throws {
    try Data(contentsOf: source).write(to: destination, options: .atomic)
  }
}
