import Foundation
import SwiftDepsToolLib
import XCTest

final class RunfilesTests: XCTestCase {
  private let rlocationpath = "rules_swift+/tools/swift"
  private var root: URL!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("RunfilesTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: root)
  }

  private func touch(_ url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: Data()))
  }

  func testResolveUsesRunfilesDirEnv() throws {
    let runfilesDir = root.appendingPathComponent("env_runfiles")
    let argv0 = root.appendingPathComponent("bin/tool").path
    let cwd = root.appendingPathComponent("cwd_runfiles/_main")
    let expected = runfilesDir.appendingPathComponent(rlocationpath)
    // Every candidate exists; RUNFILES_DIR must win.
    try touch(expected)
    try touch(URL(fileURLWithPath: argv0 + ".runfiles").appendingPathComponent(rlocationpath))
    try touch(cwd.deletingLastPathComponent().appendingPathComponent(rlocationpath))

    let actual = Runfiles.resolve(
      rlocationpath: rlocationpath, env: ["RUNFILES_DIR": runfilesDir.path],
      argv0: argv0, cwd: cwd)
    XCTAssertEqual(actual.standardizedFileURL.path, expected.standardizedFileURL.path)
  }

  func testResolveFallsBackToArgv0Runfiles() throws {
    let runfilesDir = root.appendingPathComponent("env_runfiles")
    let argv0 = root.appendingPathComponent("bin/tool").path
    let cwd = root.appendingPathComponent("cwd_runfiles/_main")
    let expected = URL(fileURLWithPath: argv0 + ".runfiles")
      .appendingPathComponent(rlocationpath)
    try touch(expected)
    try touch(cwd.deletingLastPathComponent().appendingPathComponent(rlocationpath))

    let actual = Runfiles.resolve(
      rlocationpath: rlocationpath, env: ["RUNFILES_DIR": runfilesDir.path],
      argv0: argv0, cwd: cwd)
    XCTAssertEqual(actual.standardizedFileURL.path, expected.standardizedFileURL.path)
  }

  func testResolveFallsBackToParentOfCwd() throws {
    let argv0 = root.appendingPathComponent("bin/tool").path
    let cwd = root.appendingPathComponent("cwd_runfiles/_main")
    let expected = cwd.deletingLastPathComponent().appendingPathComponent(rlocationpath)
    try touch(expected)

    let actual = Runfiles.resolve(
      rlocationpath: rlocationpath, env: [:], argv0: argv0, cwd: cwd)
    XCTAssertEqual(actual.standardizedFileURL.path, expected.standardizedFileURL.path)

    // When no candidate exists, the cwd-parent candidate is returned.
    try FileManager.default.removeItem(at: expected)
    let missing = Runfiles.resolve(
      rlocationpath: rlocationpath, env: [:], argv0: argv0, cwd: cwd)
    XCTAssertEqual(missing.standardizedFileURL.path, expected.standardizedFileURL.path)
  }
}
