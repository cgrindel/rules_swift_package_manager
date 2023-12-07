@testable import Foo
import NIO
import RxTest
import XCTest

class BarTests: XCTestCase {
    func test_sayHello() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            // swiftlint:disable force_try
            try! group.syncShutdownGracefully()
            // swiftlint:enable force_try
        }
        let eventLoop = group.next()

        let bar = Bar(name: "Joe")
        let greetingFuture = bar.sayHello(eventLoop: eventLoop)
        let greeting = try greetingFuture.wait()
        XCTAssertEqual("Hello, Joe", greeting)
    }
}
