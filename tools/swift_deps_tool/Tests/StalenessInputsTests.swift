import Foundation
import SwiftDepsToolLib
import XCTest

final class StalenessInputsTests: XCTestCase {
  private var root: URL!
  private let fileManager = FileManager.default

  override func setUpWithError() throws {
    root = fileManager.temporaryDirectory
      .appendingPathComponent("StalenessInputsTests-\(UUID().uuidString)")
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try fileManager.removeItem(at: root)
  }

  @discardableResult
  private func write(_ bytes: [UInt8], to path: String) throws -> URL {
    let url = root.appendingPathComponent(path)
    try fileManager.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(bytes).write(to: url)
    return url
  }

  private func bytes(_ text: String) -> [UInt8] { Array(text.utf8) }

  private func assertCopied(_ source: String, _ cached: String, line: UInt = #line) throws {
    XCTAssertEqual(
      try Data(contentsOf: root.appendingPathComponent(cached)),
      try Data(contentsOf: root.appendingPathComponent(source)), cached, line: line)
  }

  func testStalenessInputsAreCopiedVerbatim() throws {
    // Odd bytes on purpose: CRLF, no trailing newline, and a byte that is not valid UTF-8.
    let packageSwift = try write(bytes("// root\r\nlet x = 1") + [0xFF], to: "pkg/Package.swift")
    try write(bytes("// 5.9\n"), to: "pkg/Package@swift-5.9.swift")
    try write(bytes("// not a variant\n"), to: "pkg/Package.swift.orig")
    let resolved = try write(bytes("{\"pins\" : []}\n"), to: "slice/Package.resolved")
    let localSwift = try write(bytes("// local\n"), to: "pkg/local/Package.swift")
    try write(bytes("// local 6\n"), to: "pkg/local/Package@swift-6.0.swift")
    let registries = try write(bytes("{\"registries\": {}}\n"), to: "registries.json")
    let patch = try write(bytes("--- a\n+++ b\n"), to: "patches/swift-log.patch")
    try write(bytes("stale"), to: "cache/_main/Package@swift-5.8.swift.cached")
    try write(bytes("stale"), to: "cache/swift-log/patches/old.patch")
    let flags = try SwiftPMFlags(keyValues: ["registries": "registries.json"], workspace: root)

    try StalenessInputs.write(
      cacheDir: root.appendingPathComponent("cache"), packageSwift: packageSwift,
      sliceResolved: resolved, locals: [(identity: "local", packageSwift: localSwift)],
      flags: flags, registries: registries, patches: ["swift-log": [patch]],
      swiftVersion: "6.1.2")

    try assertCopied("pkg/Package.swift", "cache/_main/Package.swift.cached")
    try assertCopied("pkg/Package@swift-5.9.swift", "cache/_main/Package@swift-5.9.swift.cached")
    try assertCopied("slice/Package.resolved", "cache/_main/Package.resolved.cached")
    try assertCopied("registries.json", "cache/_main/registries.json.cached")
    try assertCopied("pkg/local/Package.swift", "cache/local/Package.swift.cached")
    try assertCopied(
      "pkg/local/Package@swift-6.0.swift", "cache/local/Package@swift-6.0.swift.cached")
    try assertCopied("patches/swift-log.patch", "cache/swift-log/patches/swift-log.patch")
    XCTAssertEqual(
      try String(contentsOf: root.appendingPathComponent("cache/_main/swift_version.txt")),
      "6.1.2\n")
    XCTAssertEqual(
      try fileManager.contentsOfDirectory(atPath: root.appendingPathComponent("cache/_main").path)
        .sorted(),
      [
        "Package.resolved.cached", "Package.swift.cached", "Package@swift-5.9.swift.cached",
        "flags.cached", "registries.json.cached", "swift_version.txt",
      ])
    XCTAssertEqual(
      try fileManager.contentsOfDirectory(
        atPath: root.appendingPathComponent("cache/swift-log/patches").path),
      ["swift-log.patch"])
  }

  func testFlagsCachedIsNormalized() throws {
    let packageSwift = try write(bytes("// root\n"), to: "pkg/Package.swift")
    let resolved = try write(bytes("{}\n"), to: "slice/Package.resolved")
    try write(bytes("stale"), to: "cache/_main/registries.json.cached")
    let cacheDir = root.appendingPathComponent("cache")
    let flagsCached = cacheDir.appendingPathComponent("_main/flags.cached")
    func run(_ keyValues: [String: String]) throws -> String {
      try StalenessInputs.write(
        cacheDir: cacheDir, packageSwift: packageSwift, sliceResolved: resolved, locals: [],
        flags: try SwiftPMFlags(keyValues: keyValues, workspace: root), registries: nil,
        patches: [:], swiftVersion: "6.1.0")
      return try String(contentsOf: flagsCached, encoding: .utf8)
    }

    XCTAssertEqual(
      try run(["manifest_cache": "local", "cache_path": "c", "dependency_caching": "false"]),
      "cache_path=c\ndependency_caching=false\nmanifest_cache=local\n")
    XCTAssertEqual(try run([:]), "")
    XCTAssertFalse(
      fileManager.fileExists(
        atPath: cacheDir.appendingPathComponent("_main/registries.json.cached").path))
  }
}
