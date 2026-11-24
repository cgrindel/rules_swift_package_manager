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
          swift = "//swift:Package.swift",
          resolved = "//swift/macos:Package.resolved",
          dump_manifests = {
              "_main": "//swift/macos:swift_deps_cache/_main/dump.json",
          },
          desc_manifests = {
              "_main": "//swift/macos:swift_deps_cache/_main/desc.json",
          },
      )

      """)
    XCTAssertEqual(render([]), try fixture("inc.MODULE.bazel.empty.expected"))
  }
}
