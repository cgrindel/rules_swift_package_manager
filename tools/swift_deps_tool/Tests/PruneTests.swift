import Foundation
import SwiftDepsToolLib
import XCTest

final class PruneTests: XCTestCase {
  private var root: URL!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("PruneTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: root)
  }

  func testPruneRemovesOnlyVanished() throws {
    let fileManager = FileManager.default
    for name in ["_main", "swift-log", "gone-b", "gone-a"] {
      let dir = root.appendingPathComponent(name)
      try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
      try Data("{}".utf8).write(to: dir.appendingPathComponent("dump.json"))
    }

    let removed = try Prune.removeVanished(cacheDir: root, keep: ["swift-log"])

    XCTAssertEqual(removed, ["gone-a", "gone-b"])
    XCTAssertEqual(
      try fileManager.contentsOfDirectory(atPath: root.path).sorted(), ["_main", "swift-log"])
  }

  func testPruneOfMissingCacheDirRemovesNothing() throws {
    XCTAssertEqual(
      try Prune.removeVanished(cacheDir: root.appendingPathComponent("absent"), keep: []), [])
  }
}
