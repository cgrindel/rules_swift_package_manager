import Foundation
import SwiftDepsToolLib
import XCTest

final class InvocationTests: XCTestCase {
  func testParseCacheWithAllFlags() throws {
    let args = [
      "cache",
      "--workspace", "/ws",
      "--swift-tool", "/usr/bin/swift",
      "--target-os", "macos",
      "--package", "swift/Package.swift",
      "--slice", "swift/macos",
      "--slice-package", "//swift/macos",
      "--swift-label", "//swift:Package.swift",
      "--config", "//swift:config",
      "--flag", "OPT=a=b",
      "--flag", "MODE=debug",
      "--patch", "foo=patches/foo1.patch",
      "--patch", "bar=patches/bar.patch",
      "--patch", "foo=patches/foo2.patch",
      "--patch-args", "foo=-p1",
      "--patch-args", "foo=--verbose",
    ]
    let inv = try Invocation.parse(args, env: [:])
    XCTAssertEqual(inv.command, .cache)
    XCTAssertEqual(inv.workspace, URL(fileURLWithPath: "/ws"))
    XCTAssertEqual(inv.swiftTool, URL(fileURLWithPath: "/usr/bin/swift"))
    XCTAssertEqual(inv.targetOS, "macos")
    XCTAssertEqual(inv.packagePath, "swift/Package.swift")
    XCTAssertEqual(inv.sliceDir, "swift/macos")
    XCTAssertEqual(inv.slicePackage, "//swift/macos")
    XCTAssertEqual(inv.swiftLabel, "//swift:Package.swift")
    XCTAssertEqual(inv.config, "//swift:config")
    XCTAssertEqual(inv.flags, ["OPT": "a=b", "MODE": "debug"])
    XCTAssertEqual(
      inv.patches,
      ["foo": ["patches/foo1.patch", "patches/foo2.patch"], "bar": ["patches/bar.patch"]]
    )
    XCTAssertEqual(inv.patchArgs, ["foo": ["-p1", "--verbose"]])
  }

  func testMissingCommandFails() {
    XCTAssertThrowsError(try Invocation.parse([], env: [:])) { error in
      guard let toolError = error as? ToolError else {
        return XCTFail("expected ToolError, got \(error)")
      }
      XCTAssertTrue(toolError.message.contains("resolve"), toolError.message)
      XCTAssertTrue(toolError.message.contains("update"), toolError.message)
      XCTAssertTrue(toolError.message.contains("cache"), toolError.message)
    }
  }

  func testUnknownFlagFails() {
    let args = ["cache", "--workspace", "/ws", "--bogus", "x"]
    XCTAssertThrowsError(try Invocation.parse(args, env: [:])) { error in
      guard let toolError = error as? ToolError else {
        return XCTFail("expected ToolError, got \(error)")
      }
      XCTAssertTrue(toolError.message.contains("--bogus"), toolError.message)
    }
  }
}
