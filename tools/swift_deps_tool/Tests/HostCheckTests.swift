import SwiftDepsToolLib
import XCTest

final class HostCheckTests: XCTestCase {
  func testLinuxTargetOnMacHostFails() {
    XCTAssertThrowsError(try HostCheck.check(targetOS: "linux", hostOS: "macos")) { error in
      let message = String(describing: error)
      XCTAssertTrue(message.contains("linux"), message)
      XCTAssertTrue(message.contains("macos"), message)
    }
    XCTAssertNoThrow(try HostCheck.check(targetOS: "linux", hostOS: "linux"))
  }

  func testAppleTargetOnLinuxHostFails() {
    for target in ["macos", "ios", "tvos", "watchos", "visionos"] {
      XCTAssertThrowsError(try HostCheck.check(targetOS: target, hostOS: "linux")) { error in
        let message = String(describing: error)
        XCTAssertTrue(message.contains(target), message)
        XCTAssertTrue(message.contains("linux"), message)
      }
      XCTAssertNoThrow(try HostCheck.check(targetOS: target, hostOS: "macos"))
    }
  }

  func testUnknownTargetOSFails() {
    for host in ["macos", "linux"] {
      XCTAssertThrowsError(try HostCheck.check(targetOS: "unknown", hostOS: host)) { error in
        let message = String(describing: error)
        XCTAssertTrue(message.contains("unknown"), message)
        XCTAssertTrue(message.contains(host), message)
      }
    }
  }
}
