import Foundation
import SwiftDepsToolLib
import XCTest

final class SwiftPMFlagsTests: XCTestCase {
  private let workspace = URL(fileURLWithPath: "/ws")
  private let sliceDir = URL(fileURLWithPath: "/ws/slices/macos")

  func testNormalizedIsSortedAndStable() throws {
    let pairs = [
      ("use_registry_identity_for_scm", "true"),
      ("cache_path", ".spm/cache"),
      ("manifest_cache", "local"),
      ("dependency_caching", "false"),
      ("netrc", "auth/.netrc"),
    ]
    let forward = try SwiftPMFlags(
      keyValues: Dictionary(uniqueKeysWithValues: pairs), workspace: workspace)
    let reversed = try SwiftPMFlags(
      keyValues: Dictionary(uniqueKeysWithValues: pairs.reversed()), workspace: workspace)
    let expected = """
      cache_path=.spm/cache
      dependency_caching=false
      manifest_cache=local
      netrc=auth/.netrc
      use_registry_identity_for_scm=true

      """
    XCTAssertEqual(forward.normalized(), expected)
    XCTAssertEqual(reversed.normalized(), expected)
    XCTAssertEqual(try SwiftPMFlags(keyValues: [:], workspace: workspace).normalized(), "")
  }

  func testAbsolutePathValueIsRejected() {
    for key in ["cache_path", "config_path", "security_path", "netrc", "registries"] {
      XCTAssertThrowsError(
        try SwiftPMFlags(keyValues: [key: "/tmp/x"], workspace: workspace)
      ) { error in
        let message = String(describing: error)
        XCTAssertTrue(message.contains(key), message)
      }
    }
  }

  func testEmptyPathValueIsRejected() {
    for key in ["cache_path", "config_path", "security_path", "netrc", "registries"] {
      XCTAssertThrowsError(
        try SwiftPMFlags(keyValues: [key: ""], workspace: workspace)
      ) { error in
        let message = String(describing: error)
        XCTAssertEqual(message, "configure_swift_package.\(key) must not be empty")
      }
    }
  }

  func testUnknownKeyIsRejected() {
    for key in ["build_path", "bogus"] {
      XCTAssertThrowsError(
        try SwiftPMFlags(keyValues: [key: "x"], workspace: workspace)
      ) { error in
        let message = String(describing: error)
        XCTAssertTrue(message.contains(key), message)
      }
    }
  }

  func testInvalidValueIsRejected() {
    let cases = [("dependency_caching", "yes"), ("manifest_cache", "global")]
    for (key, value) in cases {
      XCTAssertThrowsError(
        try SwiftPMFlags(keyValues: [key: value], workspace: workspace)
      ) { error in
        let message = String(describing: error)
        XCTAssertTrue(message.contains(key), message)
        XCTAssertTrue(message.contains(value), message)
      }
    }
  }

  func testArgumentsMatchV1Spelling() throws {
    let defaults = try SwiftPMFlags(keyValues: [:], workspace: workspace)
    XCTAssertEqual(
      defaults.arguments(sliceDir: sliceDir),
      [
        "--scratch-path", "/ws/slices/macos/.build",
        "--cache-path", "/ws/slices/macos/.build/.cache",
        "--config-path", "/ws/slices/macos/.build/.config",
        "--enable-dependency-cache",
        "--manifest-cache", "shared",
        "--enable-build-manifest-caching",
        "--security-path", "/ws/slices/macos/.build/.security",
      ])

    let custom = try SwiftPMFlags(
      keyValues: [
        "cache_path": "c",
        "config_path": "cfg",
        "security_path": "sec",
        "dependency_caching": "false",
        "manifest_caching": "false",
        "manifest_cache": "none",
        "replace_scm_with_registry": "true",
        "use_registry_identity_for_scm": "true",
        "netrc": "auth/.netrc",
        "registries": "registries.json",
      ],
      workspace: workspace)
    XCTAssertEqual(
      custom.arguments(sliceDir: sliceDir),
      [
        "--scratch-path", "/ws/slices/macos/.build",
        "--cache-path", "/ws/c",
        "--config-path", "/ws/cfg",
        "--disable-dependency-cache",
        "--manifest-cache", "none",
        "--disable-build-manifest-caching",
        "--netrc-file", "/ws/auth/.netrc",
        "--replace-scm-with-registry",
        "--security-path", "/ws/sec",
        "--use-registry-identity-for-scm",
      ])
  }
}
