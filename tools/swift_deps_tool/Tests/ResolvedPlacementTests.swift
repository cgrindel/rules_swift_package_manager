import Foundation
import SwiftDepsToolLib
import XCTest

final class ResolvedPlacementTests: XCTestCase {
  private struct BodyError: Error {}

  private let fileManager = FileManager.default
  private var packageDir: URL!
  private var sliceDir: URL!

  override func setUpWithError() throws {
    let root = fileManager.temporaryDirectory
      .appendingPathComponent("ResolvedPlacementTests-\(UUID().uuidString)")
    packageDir = root.appendingPathComponent("pkg")
    sliceDir = root.appendingPathComponent("slices/default")
    try fileManager.createDirectory(at: packageDir, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: sliceDir, withIntermediateDirectories: true)
  }

  private var packageResolved: URL { packageDir.appendingPathComponent("Package.resolved") }
  private var sliceResolved: URL { sliceDir.appendingPathComponent("Package.resolved") }
  private var lockDir: URL { packageDir.appendingPathComponent(".rspm_resolve_lock") }

  private func placement(isAlive: @escaping (Int32) -> Bool = { _ in false })
    -> ResolvedPlacement
  {
    ResolvedPlacement(packageDir: packageDir, sliceDir: sliceDir, pid: 4242, isAlive: isAlive)
  }

  private func write(_ text: String, to url: URL) throws {
    try text.write(to: url, atomically: true, encoding: .utf8)
  }

  private func read(_ url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
  }

  private func exists(_ url: URL) -> Bool {
    fileManager.fileExists(atPath: url.path)
  }

  private func makeLock(pid: String, slice: URL) throws {
    try fileManager.createDirectory(at: lockDir, withIntermediateDirectories: false)
    try write(pid, to: lockDir.appendingPathComponent("pid"))
    try write(slice.path, to: lockDir.appendingPathComponent("slice"))
  }

  func testCopiesInAndMovesBack() throws {
    try write("old", to: sliceResolved)
    let seen = try placement().withResolvedInPlace { () -> String in
      let text = try read(packageResolved)
      try write("new", to: packageResolved)
      return text
    }
    XCTAssertEqual(seen, "old")
    XCTAssertEqual(try read(sliceResolved), "new")
    XCTAssertFalse(exists(packageResolved))
    XCTAssertFalse(exists(lockDir))
  }

  func testRefusesV1LeftoverResolved() throws {
    try write("v1", to: packageResolved)
    var ran = false
    XCTAssertThrowsError(try placement().withResolvedInPlace { ran = true }) { error in
      let message = String(describing: error)
      XCTAssertTrue(message.contains("init --seed"), message)
      XCTAssertTrue(message.contains(packageResolved.path), message)
      XCTAssertEqual((error as? ToolError)?.slice, sliceDir.path)
    }
    XCTAssertFalse(ran)
    XCTAssertEqual(try read(packageResolved), "v1")
    XCTAssertFalse(exists(lockDir))
  }

  func testRemovesCopyOnError() throws {
    try write("old", to: sliceResolved)
    let body = {
      try self.write("new", to: self.packageResolved)
      throw BodyError()
    }
    XCTAssertThrowsError(try placement().withResolvedInPlace(body)) { error in
      XCTAssertTrue(error is BodyError)
    }
    XCTAssertFalse(exists(packageResolved))
    XCTAssertFalse(exists(lockDir))
    XCTAssertEqual(try read(sliceResolved), "new")
  }

  func testLiveLockFails() throws {
    let other = sliceDir.deletingLastPathComponent().appendingPathComponent("other")
    try makeLock(pid: "777\n", slice: other)
    var ran = false
    let placement = self.placement { $0 == 777 }
    XCTAssertThrowsError(try placement.withResolvedInPlace { ran = true }) { error in
      let message = String(describing: error)
      XCTAssertTrue(message.contains("777"), message)
      XCTAssertTrue(message.contains(other.path), message)
    }
    XCTAssertFalse(ran)
    XCTAssertTrue(exists(lockDir))
  }

  func testDeadLockIsCleared() throws {
    let other = sliceDir.deletingLastPathComponent().appendingPathComponent("other")
    try fileManager.createDirectory(at: other, withIntermediateDirectories: true)
    try write("other", to: other.appendingPathComponent("Package.resolved"))
    try write("dead copy", to: packageResolved)
    try makeLock(pid: "777", slice: other)
    try write("mine", to: sliceResolved)

    let seen = try placement { _ in false }.withResolvedInPlace { try read(packageResolved) }
    XCTAssertEqual(seen, "mine")
    XCTAssertEqual(try read(sliceResolved), "mine")
    XCTAssertEqual(try read(other.appendingPathComponent("Package.resolved")), "other")
    XCTAssertFalse(exists(packageResolved))
    XCTAssertFalse(exists(lockDir))
  }

  func testUnreadablePidIsTreatedAsDead() throws {
    try makeLock(pid: "", slice: sliceDir)
    var askedAlive = false
    let placement = self.placement { _ in
      askedAlive = true
      return true
    }
    let ran = try placement.withResolvedInPlace { true }
    XCTAssertTrue(ran)
    XCTAssertFalse(askedAlive)
    XCTAssertFalse(exists(lockDir))
  }

  func testMoveBackFailureKeepsBodyError() throws {
    let body = {
      try self.write("new", to: self.packageResolved)
      try self.fileManager.removeItem(at: self.sliceDir)
      throw BodyError()
    }
    XCTAssertThrowsError(try placement().withResolvedInPlace(body)) { error in
      XCTAssertTrue(error is BodyError, String(describing: error))
    }
    XCTAssertFalse(exists(lockDir))
  }

  func testReleaseLeavesLockItDoesNotOwn() throws {
    try placement().withResolvedInPlace {
      try write("999", to: lockDir.appendingPathComponent("pid"))
    }
    XCTAssertEqual(try read(lockDir.appendingPathComponent("pid")), "999")
  }

  func testProcessIsAliveRejectsNonPositivePIDs() {
    XCTAssertFalse(ResolvedPlacement.processIsAlive(0))
    XCTAssertFalse(ResolvedPlacement.processIsAlive(-1))
    XCTAssertTrue(ResolvedPlacement.processIsAlive(ProcessInfo.processInfo.processIdentifier))
  }

  func testFirstResolveWithNoSliceResolvedWorks() throws {
    try placement().withResolvedInPlace {
      XCTAssertFalse(exists(packageResolved))
      try write("first", to: packageResolved)
    }
    XCTAssertEqual(try read(sliceResolved), "first")
    XCTAssertFalse(exists(packageResolved))
    XCTAssertFalse(exists(lockDir))
  }
}
