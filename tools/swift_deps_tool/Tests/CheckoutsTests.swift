import Foundation
import SwiftDepsToolLib
import XCTest

final class CheckoutsTests: XCTestCase {
  private var root: URL!
  private let fileManager = FileManager.default

  override func setUpWithError() throws {
    root = fileManager.temporaryDirectory
      .appendingPathComponent("CheckoutsTests-\(UUID().uuidString)")
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try fileManager.removeItem(at: root)
  }

  private func write(_ text: String, to url: URL) throws {
    try fileManager.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
  }

  private func read(_ url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
  }

  func testPinsFromFixture() throws {
    let pins = try Checkouts.pins(resolved: Fixtures.url("Package.resolved"))
    XCTAssertEqual(pins.map(\.identity), ["swift-log", "swiftyjson"])
    XCTAssertEqual(pins.map(\.kind), ["remoteSourceControl", "remoteSourceControl"])
    XCTAssertEqual(pins[1].location, "https://github.com/SwiftyJSON/SwiftyJSON.git")

    let registry = root.appendingPathComponent("Package.resolved")
    try write(
      """
      {"pins": [{"identity": "mona.LinkedList", "kind": "registry", "location": "",
        "state": {"version": "1.0.0"}}], "version": 2}
      """, to: registry)
    XCTAssertThrowsError(try Checkouts.pins(resolved: registry)) { error in
      let text = String(describing: error)
      XCTAssertTrue(text.contains("#2699"), text)
      XCTAssertTrue(text.contains("mona.linkedlist"), text)
    }
  }

  func testPinsRejectsVersion1Format() throws {
    let resolved = root.appendingPathComponent("Package.resolved")
    try write(#"{"object": {"pins": []}, "version": 1}"#, to: resolved)
    XCTAssertThrowsError(try Checkouts.pins(resolved: resolved)) { error in
      XCTAssertTrue(String(describing: error).contains("version 1"), "\(error)")
    }
  }

  func testCheckoutDirMatchesCaseInsensitively() throws {
    let checkouts = root.appendingPathComponent("checkouts")
    for name in ["SwiftyJSON", "swift-log", "Other"] {
      try fileManager.createDirectory(
        at: checkouts.appendingPathComponent(name), withIntermediateDirectories: true)
    }
    let json = Pin(
      identity: "swiftyjson", kind: "remoteSourceControl",
      location: "https://github.com/swiftyjson/swiftyjson.git")
    XCTAssertEqual(
      try Checkouts.checkoutDir(for: json, checkoutsDir: checkouts).lastPathComponent,
      "SwiftyJSON")

    // Falls back to the identity when the location's last component matches nothing.
    let other = Pin(
      identity: "other", kind: "remoteSourceControl", location: "git@example.com:mirror.git")
    XCTAssertEqual(
      try Checkouts.checkoutDir(for: other, checkoutsDir: checkouts).lastPathComponent, "Other")

    let missing = Pin(
      identity: "missing", kind: "remoteSourceControl", location: "https://x.test/missing")
    XCTAssertThrowsError(try Checkouts.checkoutDir(for: missing, checkoutsDir: checkouts)) {
      error in
      let text = String(describing: error)
      XCTAssertTrue(text.contains("missing") && text.contains("https://x.test/missing"), text)
    }
  }

  func testPrepareAppliesPatchOnCopyNotCheckout() throws {
    let checkout = root.appendingPathComponent("checkouts/swift-log")
    try write("hello\n", to: checkout.appendingPathComponent("a.txt"))
    try write("ref\n", to: checkout.appendingPathComponent(".git/HEAD"))
    let patch = root.appendingPathComponent("fix.patch")
    try write(
      """
      --- a/a.txt
      +++ b/a.txt
      @@ -1 +1 @@
      -hello
      +world

      """, to: patch)
    let workDir = root.appendingPathComponent("rspm/swift-log")
    try write("stale\n", to: workDir.appendingPathComponent("stale.txt"))
    let pin = Pin(identity: "swift-log", kind: "remoteSourceControl", location: "x")

    let result = try Checkouts.prepare(
      pin: pin, checkout: checkout, workDir: workDir, patches: [patch], patchArgs: ["-p1"])

    XCTAssertEqual(result, workDir)
    XCTAssertEqual(try read(workDir.appendingPathComponent("a.txt")), "world\n")
    XCTAssertEqual(try read(checkout.appendingPathComponent("a.txt")), "hello\n")
    XCTAssertFalse(fileManager.fileExists(atPath: workDir.appendingPathComponent(".git").path))
    XCTAssertFalse(
      fileManager.fileExists(atPath: workDir.appendingPathComponent("stale.txt").path))
  }

  func testPrepareFailingPatchNamesPackageAndCommand() throws {
    let checkout = root.appendingPathComponent("checkouts/swift-log")
    try write("hello\n", to: checkout.appendingPathComponent("a.txt"))
    let patch = root.appendingPathComponent("bad.patch")
    try write("--- a/nope.txt\n+++ b/nope.txt\n@@ -1 +1 @@\n-x\n+y\n", to: patch)
    let pin = Pin(identity: "swift-log", kind: "remoteSourceControl", location: "x")

    XCTAssertThrowsError(
      try Checkouts.prepare(
        pin: pin, checkout: checkout, workDir: root.appendingPathComponent("rspm/swift-log"),
        patches: [patch], patchArgs: ["-p1", "-f"])
    ) { error in
      let toolError = error as? ToolError
      XCTAssertEqual(toolError?.package, "swift-log", "\(error)")
      XCTAssertTrue(toolError?.command?.hasPrefix("patch -p1 -f -i ") == true, "\(error)")
    }
  }
}
