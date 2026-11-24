import Foundation
import SwiftDepsToolLib
import XCTest

final class CacheStepTests: XCTestCase {
  private var root: URL!
  private let fileManager = FileManager.default

  override func setUpWithError() throws {
    root = fileManager.temporaryDirectory
      .appendingPathComponent("CacheStepTests-\(UUID().uuidString)")
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try fileManager.removeItem(at: root)
  }

  @discardableResult
  private func write(_ text: String, to path: String) throws -> URL {
    let url = root.appendingPathComponent(path)
    try fileManager.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
    return url
  }

  private func read(_ path: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
  }

  private func exists(_ path: String) -> Bool {
    fileManager.fileExists(atPath: root.appendingPathComponent(path).path)
  }

  /// A fake `swift`: `resolve` creates the swift-log checkout and `Package.resolved`;
  /// `dump-package` and `describe` print `desc.fake.json` from the package directory, or a
  /// description named after the directory. Every call is appended to `log.txt`.
  private func fakeTool() throws -> URL {
    let resolved = try write(
      """
      {"pins": [{"identity": "swift-log", "kind": "remoteSourceControl",
        "location": "https://github.com/apple/swift-log.git", "state": {}}], "version": 2}

      """, to: "resolved.fake.json")
    let tool = try write(
      """
      #!/bin/sh
      if [ "$1" = --version ]; then echo "Swift version 6.1.2 (fake)"; exit 0; fi
      prev=""
      for a in "$@"; do
        [ "$prev" = --scratch-path ] && scratch=$a
        prev=$a
      done
      echo "$(basename "$(pwd -P)"):$*" >> '\(root.path)/log.txt'
      case " $* " in
        *" resolve "*)
          mkdir -p "$scratch/checkouts/swift-log"
          echo '// swift-log' > "$scratch/checkouts/swift-log/Package.swift"
          cp '\(resolved.path)' Package.resolved ;;
        *)
          if [ -f desc.fake.json ]; then cat desc.fake.json
          else printf '{"name": "%s", "path": "%s/x"}' "$(basename "$(pwd -P)")" "$(pwd -P)"
          fi ;;
      esac

      """, to: "fake_swift")
    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
    return tool
  }

  private func invocation(_ command: String, slice: String = "swift/macos", tool: URL? = nil)
    throws -> Invocation
  {
    try Invocation.parse(
      [
        command, "--workspace", root.path, "--swift-tool", (tool ?? fakeTool()).path,
        "--target-os", "macos", "--package", "pkg/Package.swift", "--slice", slice,
        "--slice-package", "//\(slice)", "--swift-label", "//pkg:Package.swift", "--config",
        "@platforms//os:macos", "--patch", "swift-log=patches/fix.patch", "--patch-args",
        "swift-log=-p1",
      ], env: [:])
  }

  private func makeWorkspace() throws {
    try write("swift/macos/.build\n", to: ".bazelignore")
    try write("// root\n", to: "pkg/Package.swift")
    try write(
      #"{"name": "Root", "dependencies": [{"type": "fileSystem", "path": "LocalDir"}]}"#,
      to: "pkg/desc.fake.json")
    try write("// local\n", to: "pkg/LocalDir/Package.swift")
    try write(#"{"name": "MyLocal", "dependencies": []}"#, to: "pkg/LocalDir/desc.fake.json")
    try write(
      "--- a/Package.swift\n+++ b/Package.swift\n@@ -1 +1 @@\n-// swift-log\n+// patched\n",
      to: "patches/fix.patch")
    try write("{}", to: "swift/macos/swift_deps_cache/gone/dump.json")
  }

  func testRefusesWithoutBazelignoreEntry() throws {
    try makeWorkspace()
    try write("other/.build\n", to: ".bazelignore")
    XCTAssertThrowsError(try CacheStep(invocation("cache")).run()) { error in
      let toolError = error as? ToolError
      XCTAssertEqual(toolError?.slice, "swift/macos", "\(error)")
      XCTAssertTrue(
        toolError?.message.contains("@rules_swift_package_manager//tools:init") == true,
        "\(error)")
    }
  }

  func testResolveThenCacheWritesCacheAndIncModule() throws {
    try makeWorkspace()
    let cache = "swift/macos/swift_deps_cache"

    try CacheStep(invocation("resolve")).run()

    XCTAssertEqual(
      try fileManager.contentsOfDirectory(atPath: root.appendingPathComponent(cache).path)
        .sorted(), ["_main", "localdir", "swift-log"])
    for id in ["_main", "localdir", "swift-log"] {
      XCTAssertTrue(exists("\(cache)/\(id)/dump.json"), id)
      XCTAssertTrue(exists("\(cache)/\(id)/desc.json"), id)
    }
    XCTAssertEqual(try read("\(cache)/localdir/Package.swift.cached"), "// local\n")
    XCTAssertEqual(try read("\(cache)/_main/Package.swift.cached"), "// root\n")
    XCTAssertEqual(try read("\(cache)/_main/swift_version.txt"), "6.1.2\n")
    XCTAssertEqual(try read("\(cache)/swift-log/patches/fix.patch"), try read("patches/fix.patch"))
    XCTAssertEqual(
      try read("swift/macos/.build/rspm/swift-log/Package.swift"), "// patched\n")
    XCTAssertEqual(
      try read("swift/macos/.build/checkouts/swift-log/Package.swift"), "// swift-log\n")
    XCTAssertTrue(exists("swift/macos/Package.resolved"))
    XCTAssertFalse(exists("pkg/Package.resolved"))
    let incModule = try read("swift/macos/inc.MODULE.bazel")
    XCTAssertEqual(
      incModule,
      """
      swift_deps = use_extension("@rules_swift_package_manager//:extensions.bzl", "swift_deps")
      swift_deps.from_package(
          config = "@platforms//os:macos",
          desc_manifests = {
              "_main": "//swift/macos:swift_deps_cache/_main/desc.json",
              "localdir": "//swift/macos:swift_deps_cache/localdir/desc.json",
              "swift-log": "//swift/macos:swift_deps_cache/swift-log/desc.json",
          },
          dump_manifests = {
              "_main": "//swift/macos:swift_deps_cache/_main/dump.json",
              "localdir": "//swift/macos:swift_deps_cache/localdir/dump.json",
              "swift-log": "//swift/macos:swift_deps_cache/swift-log/dump.json",
          },
          resolved = "//swift/macos:Package.resolved",
          swift = "//pkg:Package.swift",
      )

      """)
    // A local package's identity is its directory name, as SwiftPM's, not its package name.
    XCTAssertFalse(exists("\(cache)/mylocal"))
    // The root and each local package are described exactly once.
    let log = try read("log.txt").split(separator: "\n")
    XCTAssertEqual(
      log.filter { $0.hasPrefix("pkg:") && $0.hasSuffix("describe --type json") }
        .count, 1)
    XCTAssertEqual(
      log.filter { $0.hasPrefix("LocalDir:") && $0.hasSuffix("describe --type json") }.count, 1)

    // A cache-only rerun checks the pins without changing them and writes identical output.
    let dump = try read("\(cache)/swift-log/dump.json")
    try fileManager.removeItem(at: root.appendingPathComponent("log.txt"))
    try CacheStep(invocation("cache")).run()
    XCTAssertEqual(try read("swift/macos/inc.MODULE.bazel"), incModule)
    XCTAssertEqual(try read("\(cache)/swift-log/dump.json"), dump)
    XCTAssertTrue(
      try read("log.txt").split(separator: "\n").first?
        .hasSuffix("resolve --force-resolved-versions") == true)
  }

  func testRefusesSliceInPackageDir() throws {
    try makeWorkspace()
    try write("pkg/.build\n", to: ".bazelignore")
    for slice in ["pkg", "pkg/"] {
      XCTAssertThrowsError(try CacheStep(invocation("resolve", slice: slice)).run()) { error in
        let message = String(describing: error)
        XCTAssertTrue(
          message.contains("must differ from the directory of pkg/Package.swift"), message)
      }
    }
    XCTAssertFalse(exists("log.txt"))
  }

  func testCacheWithoutSliceResolvedSaysToResolveFirst() throws {
    try makeWorkspace()
    let tool = try write(
      """
      #!/bin/sh
      if [ "$1" = --version ]; then echo "Swift version 6.1.2 (fake)"; exit 0; fi
      echo "error: a resolved file is required" >&2
      exit 1

      """, to: "failing_swift")
    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
    XCTAssertThrowsError(try CacheStep(invocation("cache", tool: tool)).run()) { error in
      let message = (error as? ToolError)?.message ?? "\(error)"
      XCTAssertTrue(
        message.hasPrefix(
          "no `Package.resolved` in slice `swift/macos`; run "
            + "`bazel run @swift_package//:resolve` under flags that select this slice first"),
        message)
      XCTAssertTrue(message.contains("a resolved file is required"), message)
    }

    // With a slice file, SwiftPM's error passes through unchanged.
    try write("{}", to: "swift/macos/Package.resolved")
    XCTAssertThrowsError(try CacheStep(invocation("cache", tool: tool)).run()) { error in
      let message = (error as? ToolError)?.message ?? "\(error)"
      XCTAssertEqual(message, "error: a resolved file is required", message)
    }
  }
}
