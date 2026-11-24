import Foundation
import SwiftDepsToolLib
import XCTest

final class PathRelativizerTests: XCTestCase {
  private let root = URL(fileURLWithPath: "/w/pkg")

  /// `workspace` defaults to a root that contains none of the test paths, so only pass 1 runs.
  private func relativize(
    _ text: String, packageRoot: URL? = nil, workspace: String = "/elsewhere"
  ) -> String {
    let output = PathRelativizer.relativize(
      Data(text.utf8), packageRoot: packageRoot ?? root,
      workspaceRoot: URL(fileURLWithPath: workspace))
    return String(decoding: output, as: UTF8.self)
  }

  func testRelativizeReplacesRootPrefixOnly() {
    let input = """
      {
        "other" : "/w/pkgOther/Sources",
        "path" : "/w/pkg/Sources/Foo",
        "plain" : "unchanged"
      }
      """
    let expected = """
      {
        "other" : "/w/pkgOther/Sources",
        "path" : "./Sources/Foo",
        "plain" : "unchanged"
      }
      """
    XCTAssertEqual(relativize(input), expected)
  }

  func testRelativizeHandlesRootAsWholeValue() {
    XCTAssertEqual(
      relativize("{\n  \"path\": \"/w/pkg\"\n}\n"), "{\n  \"path\": \"./\"\n}\n")
  }

  func testRelativizeRewritesWorkspacePathsAsParentRelative() {
    let input = """
      {"dep": "/w/third_party/MyAmazingModule", "own": "/w/third_party/notthatamazingmodule/S",
       "top": "/w", "src": "/w/Sources/X", "trap": "/wx/foo", "in": "a /w/b c"}
      """
    let expected = """
      {"dep": "../MyAmazingModule", "own": "./S",
       "top": "../..", "src": "../../Sources/X", "trap": "/wx/foo", "in": "a /w/b c"}
      """
    XCTAssertEqual(
      relativize(
        input, packageRoot: URL(fileURLWithPath: "/w/third_party/notthatamazingmodule"),
        workspace: "/w"),
      expected)
  }

  func testRelativizeLeavesPathsOutsideWorkspaceAbsolute() {
    let input = #"{"a": "/opt/sdk/lib", "b": "/w/pkg/x", "c": "/opt/sdk/lib", "d": "rel"}"#
    let output = relativize(input, workspace: "/w")
    XCTAssertEqual(output, #"{"a": "/opt/sdk/lib", "b": "./x", "c": "/opt/sdk/lib", "d": "rel"}"#)
    XCTAssertEqual(PathRelativizer.absolutePaths(in: Data(output.utf8)), ["/opt/sdk/lib"])
  }
}
