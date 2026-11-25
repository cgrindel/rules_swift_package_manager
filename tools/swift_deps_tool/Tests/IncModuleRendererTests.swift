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
  private func renderWithCanonicalArgs(_ incModule: URL) -> String {
    IncModuleRenderer.render(
      labels: IncModuleFile.labels(
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

    XCTAssertEqual(renderWithCanonicalArgs(incModule), render(["_main"]))
  }

  func testRenderUsesArgsWhenNoFile() throws {
    let incModule = try tempDir().appendingPathComponent("inc.MODULE.bazel")
    XCTAssertNil(IncModuleFile.existingValues(at: incModule))

    let text = renderWithCanonicalArgs(incModule)
    XCTAssertTrue(text.contains("    config = \"@@platforms//os:macos\",\n"), text)
    XCTAssertTrue(text.contains("    swift = \"@@//swift:Package.swift\",\n"), text)
    XCTAssertTrue(text.contains("    resolved = \"@@//swift/macos:Package.resolved\",\n"), text)
    XCTAssertTrue(
      text.contains("\"_main\": \"@@//swift/macos:swift_deps_cache/_main/dump.json\""), text)
  }
}
