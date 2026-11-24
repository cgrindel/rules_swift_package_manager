import Foundation
import SwiftDepsToolLib
import XCTest

final class SwiftPMTests: XCTestCase {
  private var root: URL!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftPMTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: root)
  }

  /// Writes an executable `/bin/sh` script named `tool` into `root`.
  private func fakeTool(_ body: String) throws -> URL {
    let tool = root.appendingPathComponent("tool")
    try Data("#!/bin/sh\n\(body)\n".utf8).write(to: tool)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
    return tool
  }

  private func swiftPM(tool: URL, keyValues: [String: String] = [:]) throws -> SwiftPM {
    let flags = try SwiftPMFlags(keyValues: keyValues, workspace: root)
    return SwiftPM(tool: tool, flags: flags, sliceDir: root.appendingPathComponent("slice"))
  }

  func testVersionParsesAppleAndLinuxOutput() throws {
    let fixtures = [
      (
        "swift-driver version: 1.120.5 Apple Swift version 6.1 "
          + "(swiftlang-6.1.0.110.21 clang-1700.0.13.3)\nTarget: arm64-apple-macosx15.0",
        "6.1.0"
      ),
      ("Swift version 6.0.3 (swift-6.0.3-RELEASE)\nTarget: x86_64-unknown-linux-gnu", "6.0.3"),
    ]
    for (output, expected) in fixtures {
      let fixture = root.appendingPathComponent("fixture.txt")
      try Data(output.utf8).write(to: fixture)
      let tool = try fakeTool("[ \"$1\" = --version ] || exit 3\ncat '\(fixture.path)'")
      XCTAssertEqual(try swiftPM(tool: tool).version(), expected)
    }
  }

  func testVersionWithoutMatchThrows() throws {
    let tool = try fakeTool("echo 'no version here'")
    XCTAssertThrowsError(try swiftPM(tool: tool).version()) { error in
      XCTAssertTrue(String(describing: error).contains("no version here"), "\(error)")
    }
  }

  func testRunPassesArgumentsInPackageDirAndReturnsStdout() throws {
    let argvFile = root.appendingPathComponent("argv.txt")
    let pwdFile = root.appendingPathComponent("pwd.txt")
    let tool = try fakeTool(
      "for arg in \"$@\"; do echo \"$arg\"; done > '\(argvFile.path)'\n"
        + "pwd > '\(pwdFile.path)'\necho out")
    let packageDir = root.appendingPathComponent("pkg")
    try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)
    let swiftPM = try swiftPM(tool: tool)

    let stdout = try swiftPM.run(["dump-package"], in: packageDir)
    XCTAssertEqual(String(decoding: stdout, as: UTF8.self), "out\n")
    let flags = try SwiftPMFlags(keyValues: [:], workspace: root)
    let sliceArgs = flags.arguments(sliceDir: root.appendingPathComponent("slice"))
    let expected = ["package"] + sliceArgs + ["dump-package"]
    XCTAssertEqual(try String(contentsOf: argvFile, encoding: .utf8), lines(expected))
    let pwd = try String(contentsOf: pwdFile, encoding: .utf8)
      .trimmingCharacters(in: .newlines)
    XCTAssertEqual(
      URL(fileURLWithPath: pwd).resolvingSymlinksInPath(),
      packageDir.resolvingSymlinksInPath())

    let scratch = root.appendingPathComponent("rspm/foo/.build")
    try swiftPM.run(["describe"], in: packageDir, scratchPath: scratch)
    var overridden = expected
    overridden[2] = scratch.path
    overridden[overridden.count - 1] = "describe"
    XCTAssertEqual(try String(contentsOf: argvFile, encoding: .utf8), lines(overridden))
  }

  func testRunFailureReportsCommandAndStderrTail() throws {
    let tool = try fakeTool(
      "i=1; while [ $i -le 25 ]; do echo \"err $i\" >&2; i=$((i+1)); done; exit 1")
    XCTAssertThrowsError(try swiftPM(tool: tool).run(["resolve"], in: root)) { error in
      guard let toolError = error as? ToolError else {
        return XCTFail("unexpected error \(error)")
      }
      XCTAssertEqual(toolError.command, "swift package resolve")
      XCTAssertEqual(toolError.message, (6...25).map { "err \($0)" }.joined(separator: "\n"))
    }
  }

  func testRunLinksRegistriesIntoConfigPath() throws {
    let registries = root.appendingPathComponent("my_registries.json")
    try Data("{}".utf8).write(to: registries)
    let tool = try fakeTool("exit 0")
    let swiftPM = try swiftPM(
      tool: tool, keyValues: ["registries": "my_registries.json", "config_path": "cfg"])

    try swiftPM.run(["resolve"], in: root)
    let link = root.appendingPathComponent("cfg/registries.json")
    XCTAssertEqual(
      try FileManager.default.destinationOfSymbolicLink(atPath: link.path), registries.path)
    // A second run replaces the link rather than failing.
    try swiftPM.run(["resolve"], in: root)
  }

  private func lines(_ values: [String]) -> String {
    values.map { $0 + "\n" }.joined()
  }
}
