import Foundation
import SwiftDepsToolLib
import XCTest

final class PathRelativizerTests: XCTestCase {
  private let root = URL(fileURLWithPath: "/w/pkg")

  private func relativize(_ text: String) -> String {
    let output = PathRelativizer.relativize(Data(text.utf8), packageRoot: root)
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
}
