import Foundation
import SwiftDepsToolLib
import XCTest

final class ManifestsTests: XCTestCase {
  private var root: URL!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ManifestsTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: root)
  }

  /// Returns a `SwiftPM` whose tool echoes `{"name": "<cmd>", "path": "$PWD/x"}`, or fails.
  private func swiftPM(failing: Bool = false) throws -> SwiftPM {
    let tool = root.appendingPathComponent("tool")
    let body =
      failing
      ? "echo boom >&2; exit 1"
      : "for a in \"$@\"; do last=$a; done\n"
        + "printf '{\"name\" : \"%s\", \"path\" : \"%s/x\"}' \"$last\" \"$(pwd -P)\""
    try Data("#!/bin/sh\n\(body)\n".utf8).write(to: tool)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
    let flags = try SwiftPMFlags(keyValues: [:], workspace: root)
    return SwiftPM(tool: tool, flags: flags, sliceDir: root.appendingPathComponent("slice"))
  }

  func testWriteStoresRelativizedDumpAndDesc() throws {
    let package = root.appendingPathComponent("MyPkg")
    try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
    let cacheDir = root.appendingPathComponent("cache/MyPkg")

    let desc = try Manifests.write(
      package: package, cacheDir: cacheDir, workspace: root, spm: swiftPM(), scratchPath: nil)

    XCTAssertEqual(desc.identity, "json")
    let read = { (name: String) in
      try String(contentsOf: cacheDir.appendingPathComponent(name), encoding: .utf8)
    }
    XCTAssertEqual(try read("dump.json"), "{\"name\" : \"dump-package\", \"path\" : \"./x\"}")
    XCTAssertEqual(try read("desc.json"), "{\"name\" : \"json\", \"path\" : \"./x\"}")
  }

  func testWriteFailureNamesPackage() throws {
    let package = root.appendingPathComponent("MyPkg")
    try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
    XCTAssertThrowsError(
      try Manifests.write(
        package: package, cacheDir: root.appendingPathComponent("cache"), workspace: root,
        spm: swiftPM(failing: true), scratchPath: nil)
    ) { error in
      XCTAssertEqual((error as? ToolError)?.package, "MyPkg", "\(error)")
    }
  }
}
