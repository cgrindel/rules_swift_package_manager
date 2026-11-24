import Foundation
import SwiftDepsToolLib
import XCTest

final class LocalPackagesTests: XCTestCase {
  private var root: URL!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("LocalPackagesTests-\(UUID().uuidString)")
      .appendingPathComponent("root")
  }

  /// Maps a package directory to `desc_<last path component>.json`.
  private func readDesc(_ package: URL) throws -> Desc {
    try Desc(data: Fixtures.data("desc_\(package.lastPathComponent).json"))
  }

  func testDiscoverReachesFixedPointAndVisitsEachOnce() throws {
    var reads: [String] = []
    let found = try LocalPackages.discover(root: root) { package in
      reads.append(package.lastPathComponent)
      return try self.readDesc(package)
    }
    XCTAssertEqual(found.map(\.lastPathComponent), ["local_a", "local_b"])
    XCTAssertEqual(reads, ["root", "local_a", "local_b"])
  }

  func testDiscoverResolvesRelativePathsAgainstPackage() throws {
    let found = try LocalPackages.discover(root: root, readDesc: readDesc)
    let localA = root.appendingPathComponent("local_a")
    XCTAssertEqual(
      found.map(\.path),
      [localA.path, localA.appendingPathComponent("local_b").path])
  }

  func testDescReadsIdentityAndFileSystemPaths() throws {
    let desc = try readDesc(root.appendingPathComponent("local_a"))
    XCTAssertEqual(desc.identity, "locala")
    XCTAssertEqual(desc.fileSystemDependencyPaths, ["./local_b", ".."])
  }
}
