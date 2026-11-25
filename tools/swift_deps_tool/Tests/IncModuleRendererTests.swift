import Foundation
import SwiftDepsToolLib
import XCTest

final class IncModuleRendererTests: XCTestCase {
  private func render(_ identities: [String]) -> String {
    IncModuleRenderer.render(
      config: "@platforms//os:macos", swiftLabel: "//swift:Package.swift",
      resolvedLabel: "//swift/macos:Package.resolved", slicePackage: "//swift/macos",
      identities: identities)
  }

  private func fixture(_ name: String) throws -> String {
    String(decoding: try Fixtures.data(name), as: UTF8.self)
  }

  func testRenderIsSortedAndStable() throws {
    let expected = try fixture("inc.MODULE.bazel.expected")
    XCTAssertEqual(render(["swift-log", "_main"]), expected)
    XCTAssertEqual(render(["_main", "swift-log"]), expected)
  }

  func testRenderWithNoDependenciesHasOnlyMain() throws {
    XCTAssertEqual(
      render(["_main"]),
      """
      swift_deps = use_extension("@rules_swift_package_manager//:extensions.bzl", "swift_deps")
      swift_deps.from_package(
          config = "@platforms//os:macos",
          desc_manifests = {
              "_main": "//swift/macos:swift_deps_cache/_main/desc.json",
          },
          dump_manifests = {
              "_main": "//swift/macos:swift_deps_cache/_main/dump.json",
          },
          resolved = "//swift/macos:Package.resolved",
          swift = "//swift:Package.swift",
      )

      """)
    XCTAssertEqual(render([]), try fixture("inc.MODULE.bazel.empty.expected"))
  }

  private func tempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("IncModuleRendererTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
    return dir
  }

  /// Canonical labels, as the extension passes them to the tool.
  private func renderWithCanonicalArgs(_ incModule: URL) throws -> String {
    IncModuleRenderer.render(
      labels: try IncModuleFile.labels(
        at: incModule, config: "@@platforms//os:macos",
        swiftLabel: "@@//swift:Package.swift", slicePackage: "@@//swift/macos"),
      identities: ["_main"])
  }

  func testRenderPreservesExistingLabels() throws {
    let incModule = try tempDir().appendingPathComponent("inc.MODULE.bazel")
    try Data(
      """
      swift_deps = use_extension("@rules_swift_package_manager//:extensions.bzl", "swift_deps")
      swift_deps.from_package(
          config = "@platforms//os:macos",
          swift = "//swift:Package.swift",
          resolved = "//swift/macos:Package.resolved",
          dump_manifests = {},
          desc_manifests = {},
      )

      """.utf8
    ).write(to: incModule)

    XCTAssertEqual(try renderWithCanonicalArgs(incModule), render(["_main"]))
  }

  func testRenderUsesArgsWhenNoFile() throws {
    let incModule = try tempDir().appendingPathComponent("inc.MODULE.bazel")
    XCTAssertNil(IncModuleFile.existingValues(at: incModule))

    let text = try renderWithCanonicalArgs(incModule)
    XCTAssertTrue(text.contains("    config = \"@@platforms//os:macos\",\n"), text)
    XCTAssertTrue(text.contains("    swift = \"@@//swift:Package.swift\",\n"), text)
    XCTAssertTrue(text.contains("    resolved = \"@@//swift/macos:Package.resolved\",\n"), text)
    XCTAssertTrue(
      text.contains("\"_main\": \"@@//swift/macos:swift_deps_cache/_main/dump.json\""), text)
  }

  /// A file as `init` writes it, with `extra` lines added to the tag before the closing `)`.
  private func writeIncModule(_ extra: String) throws -> URL {
    let incModule = try tempDir().appendingPathComponent("inc.MODULE.bazel")
    try Data(
      ("""
      swift_deps = use_extension("@rules_swift_package_manager//:extensions.bzl", "swift_deps")
      swift_deps.from_package(
          config = "@platforms//os:macos",
          desc_manifests = {},
          dump_manifests = {},
          resolved = "//swift/macos:Package.resolved",
          swift = "//swift:Package.swift",

      """ + extra + ")\n").utf8
    ).write(to: incModule)
    return incModule
  }

  func testRenderKeepsUserAttributes() throws {
    let incModule = try writeIncModule(
      """
          netrc = "//:.netrc",
          make_files_read_only = True,
          registries = "@my_registry//:registries.json",

      """)

    XCTAssertEqual(
      try renderWithCanonicalArgs(incModule),
      """
      swift_deps = use_extension("@rules_swift_package_manager//:extensions.bzl", "swift_deps")
      swift_deps.from_package(
          config = "@platforms//os:macos",
          desc_manifests = {
              "_main": "//swift/macos:swift_deps_cache/_main/desc.json",
          },
          dump_manifests = {
              "_main": "//swift/macos:swift_deps_cache/_main/dump.json",
          },
          make_files_read_only = True,
          netrc = "//:.netrc",
          registries = "@my_registry//:registries.json",
          resolved = "//swift/macos:Package.resolved",
          swift = "//swift:Package.swift",
      )

      """)
  }

  func testRenderRoundTripsUserAttributes() throws {
    let incModule = try writeIncModule(
      """
          make_files_read_only = True,
          netrc = "//:.netrc",

      """)
    let first = try renderWithCanonicalArgs(incModule)
    try Data(first.utf8).write(to: incModule)
    XCTAssertEqual(try renderWithCanonicalArgs(incModule), first)
  }

  func testRenderKeepsUnknownMultilineAttributeVerbatim() throws {
    let incModule = try writeIncModule(
      """
          zz_future = [
              "a]",
              "b",
          ],

      """)
    let text = try renderWithCanonicalArgs(incModule)
    XCTAssertTrue(
      text.hasSuffix(
        """
            swift = "//swift:Package.swift",
            zz_future = [
                "a]",
                "b",
            ],
        )

        """), text)
  }

  func testBracketsInsideStringsDoNotNest() throws {
    let incModule = try writeIncModule("    odd = \"[{(\\\"\",\n")
    XCTAssertEqual(
      try IncModuleFile.extraAttributes(at: incModule),
      [IncModuleFile.Attribute(name: "odd", value: "\"[{(\\\"\"")])
  }

  func testMalformedLineFailsNamingTheFile() throws {
    let incModule = try writeIncModule("    netrc \"//:.netrc\"\n")
    XCTAssertThrowsError(
      try IncModuleFile.labels(
        at: incModule, config: "c", swiftLabel: "s", slicePackage: "//p")
    ) { error in
      let text = String(describing: error)
      XCTAssertTrue(text.contains(incModule.path), text)
      XCTAssertTrue(text.contains("line 8"), text)
    }
  }

  private func assertCommentFails(_ incModule: URL, line: Int) {
    XCTAssertThrowsError(try IncModuleFile.extraAttributes(at: incModule)) { error in
      XCTAssertEqual(
        (error as? ToolError)?.message,
        "cannot parse \(incModule.path) line \(line): comments are not supported in "
          + "inc.MODULE.bazel; put them in MODULE.bazel")
    }
  }

  func testCommentLineFails() throws {
    assertCommentFails(try writeIncModule("    # keep me\n"), line: 8)
  }

  func testTrailingCommentFails() throws {
    assertCommentFails(try writeIncModule("    netrc = \"//:.netrc\",  # keep me\n"), line: 8)
  }

  func testCommentInsideMultilineValueFails() throws {
    assertCommentFails(
      try writeIncModule("    registries = [\n        # keep me\n        \"a\",\n    ],\n"),
      line: 9)
  }

  private func writeRaw(_ text: String) throws -> URL {
    let incModule = try tempDir().appendingPathComponent("inc.MODULE.bazel")
    try Data(text.utf8).write(to: incModule)
    return incModule
  }

  private let tag = """
    swift_deps.from_package(
        config = "@platforms//os:macos",
        resolved = "//swift/macos:Package.resolved",
        swift = "//swift:Package.swift",
    )

    """

  private func assertStrayContentFails(_ incModule: URL, line: Int) {
    XCTAssertThrowsError(
      try IncModuleFile.labels(
        at: incModule, config: "c", swiftLabel: "s", slicePackage: "//p")
    ) { error in
      let message = (error as? ToolError)?.message ?? "\(error)"
      XCTAssertTrue(
        message.hasPrefix(
          "cannot parse \(incModule.path) line \(line): unexpected content outside the "
            + "`swift_deps.from_package(` tag; the tool owns this file"),
        message)
      XCTAssertTrue(message.hasSuffix("Put other tags and statements in the root MODULE.bazel"))
    }
  }

  func testCommentOutsideTheTagFails() throws {
    assertCommentFails(
      try writeRaw("# keep me\n" + IncModuleFile.useExtensionLine + "\n" + tag), line: 1)
  }

  func testOtherTagAfterTheCallFails() throws {
    assertStrayContentFails(
      try writeRaw(
        IncModuleFile.useExtensionLine + "\n" + tag
          + "swift_deps.configure_package(\n    name = \"swift-log\",\n)\n"),
      line: 7)
  }

  func testSecondFromPackageTagFails() throws {
    assertStrayContentFails(
      try writeRaw(IncModuleFile.useExtensionLine + "\n" + tag + tag), line: 7)
  }

  func testDifferentUseExtensionLineFails() throws {
    assertStrayContentFails(
      try writeRaw(
        #"swift_deps = use_extension("//:extensions.bzl", "swift_deps")"# + "\n" + tag),
      line: 1)
  }

  func testFileWithOnlyTheToolsLinesParses() throws {
    let incModule = try writeRaw("\n" + IncModuleFile.useExtensionLine + "\n\n" + tag + "\n")
    XCTAssertEqual(try IncModuleFile.extraAttributes(at: incModule), [])
  }

  func testMissingCommaFails() throws {
    let incModule = try writeIncModule("    netrc = \"//:.netrc\"\n")
    XCTAssertThrowsError(try IncModuleFile.extraAttributes(at: incModule))
  }

  func testDuplicateAttributeFails() throws {
    let incModule = try writeIncModule("    swift = \"//other:Package.swift\",\n")
    XCTAssertThrowsError(try IncModuleFile.extraAttributes(at: incModule))
  }
}
