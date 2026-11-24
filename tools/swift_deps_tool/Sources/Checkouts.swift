import Foundation

/// One entry of `Package.resolved`.
public struct Pin: Equatable {
  /// SwiftPM's identity, lower-cased.
  public var identity: String
  /// `remoteSourceControl`, `localSourceControl`, or `registry`.
  public var kind: String
  public var location: String

  public init(identity: String, kind: String, location: String) {
    self.identity = identity
    self.kind = kind
    self.location = location
  }
}

/// Reads pins and prepares a patched copy of each checkout for dumping.
public enum Checkouts {
  /// Parses a version 2 or 3 `Package.resolved`. Registry pins are not supported yet (#2699).
  public static func pins(resolved: URL) throws -> [Pin] {
    let data = try Data(contentsOf: resolved)
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ToolError(message: "\(resolved.path) is not a JSON object")
    }
    if object["version"] as? Int == 1 {
      throw ToolError(
        message: "\(resolved.path) uses the Package.resolved version 1 format; "
          + "run `swift package resolve` with Swift 5.6 or later to upgrade it")
    }
    guard let entries = object["pins"] as? [[String: Any]] else {
      throw ToolError(message: "\(resolved.path) has no pins list")
    }
    return try entries.map { entry in
      guard let identity = entry["identity"] as? String,
        let kind = entry["kind"] as? String,
        let location = entry["location"] as? String
      else {
        throw ToolError(message: "\(resolved.path) has a pin without identity, kind or location")
      }
      let pin = Pin(identity: identity.lowercased(), kind: kind, location: location)
      if kind == "registry" {
        throw ToolError(
          package: pin.identity,
          message: "registry dependency '\(pin.identity)' is not supported yet; see #2699")
      }
      return pin
    }
  }

  /// Finds the pin's directory under `.build/checkouts/`. SwiftPM names it after the last
  /// component of the location without `.git`; the identity is the fallback. Case is ignored.
  public static func checkoutDir(for pin: Pin, checkoutsDir: URL) throws -> URL {
    let entries =
      (try? FileManager.default.contentsOfDirectory(atPath: checkoutsDir.path)) ?? []
    for wanted in [basename(pin.location), pin.identity] {
      if let match = entries.first(where: { $0.lowercased() == wanted.lowercased() }) {
        return checkoutsDir.appendingPathComponent(match, isDirectory: true)
      }
    }
    throw ToolError(
      package: pin.identity,
      message: "no checkout for \(pin.location) under \(checkoutsDir.path)")
  }

  /// Copies `checkout` to `workDir` without `.git`, then applies each patch there with exactly
  /// `patchArgs`, as `swift_package`'s `patch()` does. Returns `workDir`.
  public static func prepare(
    pin: Pin, checkout: URL, workDir: URL, patches: [URL], patchArgs: [String]
  ) throws -> URL {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: workDir.path) {
      try fileManager.removeItem(at: workDir)
    }
    try fileManager.createDirectory(
      at: workDir.deletingLastPathComponent(), withIntermediateDirectories: true)
    try fileManager.copyItem(at: checkout, to: workDir)
    let git = workDir.appendingPathComponent(".git")
    if fileManager.fileExists(atPath: git.path) {
      try fileManager.removeItem(at: git)
    }
    for patch in patches {
      try applyPatch(patch, args: patchArgs, in: workDir, identity: pin.identity)
    }
    return workDir
  }

  /// The last path component of a URL, path, or `host:path` location, without `.git`.
  private static func basename(_ location: String) -> String {
    var name = location
    while name.hasSuffix("/") { name.removeLast() }
    if let separator = name.lastIndex(where: { $0 == "/" || $0 == ":" }) {
      name = String(name[name.index(after: separator)...])
    }
    return name.hasSuffix(".git") ? String(name.dropLast(4)) : name
  }

  private static func applyPatch(_ patch: URL, args: [String], in dir: URL, identity: String)
    throws
  {
    let patchArgs = args + ["-i", patch.path]
    let command = (["patch"] + patchArgs).joined(separator: " ")
    let process = Process()
    let direct = "/usr/bin/patch"
    if FileManager.default.isExecutableFile(atPath: direct) {
      process.executableURL = URL(fileURLWithPath: direct)
      process.arguments = patchArgs
    } else {
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = ["patch"] + patchArgs
    }
    process.currentDirectoryURL = dir
    process.standardInput = FileHandle.nullDevice
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    do {
      try process.run()
    } catch {
      throw ToolError(package: identity, command: command, message: "failed to launch: \(error)")
    }
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw ToolError(
        package: identity, command: command,
        message: "patch failed: \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
  }
}
