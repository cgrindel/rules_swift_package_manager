@testable import LottieExample
import XCTest

final class LottieExampleUITests: XCTestCase {
    override func setUp() {
        super.setUp()

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test.
        // Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state
        // - such as interface orientation - required for your tests before they run.
        // The setUp method is a good place to do this.
    }

    func testExampleRuns() {
        // Extremely simple UI test which is designed to run and display the example project
        // This should show if there are any very obvious crashes on render
        let app = XCUIApplication()
        let running = app.wait(for: .runningForeground, timeout: 300)
        XCTAssertEqual(running, true, "app is running in the foreground")
    }
}
