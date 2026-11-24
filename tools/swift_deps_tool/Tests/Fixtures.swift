import Foundation

/// Locates files under `Tests/fixtures` through the Bazel test runfiles tree.
enum Fixtures {
  static func url(_ name: String) -> URL {
    let env = ProcessInfo.processInfo.environment
    guard let srcdir = env["TEST_SRCDIR"], let workspace = env["TEST_WORKSPACE"] else {
      fatalError("TEST_SRCDIR and TEST_WORKSPACE must be set; run the tests with bazel test")
    }
    return URL(fileURLWithPath: srcdir)
      .appendingPathComponent(workspace)
      .appendingPathComponent("tools/swift_deps_tool/Tests/fixtures")
      .appendingPathComponent(name)
  }

  static func data(_ name: String) throws -> Data {
    try Data(contentsOf: url(name))
  }
}
