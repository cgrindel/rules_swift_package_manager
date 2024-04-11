//
//  PaymentSheetUITestCase.swift
//  PaymentSheetUITest
//
//  Created by David Estes on 1/21/21.
//  Copyright © 2021 stripe-ios. All rights reserved.
//

import XCTest

class PaymentSheetUITestCase: XCTestCase {
    var app: XCUIApplication!

    /// This element's `label` contains all the analytic events sent by the SDK since the the playground was loaded, as a base-64 encoded string.
    /// - Note: Only exists in test playground.
    lazy var analyticsLogElement: XCUIElement = { app.staticTexts["_testAnalyticsLog"] }()
    /// Convenience var to grab all the events sent since the playground was loaded.
    var analyticsLog: [[String: Any]] {
        let logRawString = analyticsLogElement.label
        guard
            let data = Data(base64Encoded: logRawString),
            let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return []
        }
        return json
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchEnvironment = [
            "UITesting": "true",
            // This makes the Financial Connections SDK trigger the (testmode) production flow instead of a stub. See FinancialConnectionsSDKAvailability.isUnitTestOrUITest.
            "USE_PRODUCTION_FINANCIAL_CONNECTIONS_SDK": "true",
        ]
    }
}

class PaymentSheetDeferredServerSideUITests: PaymentSheetUITestCase {
    func testCVCRecollectionComplete_intentFirstCSC() throws {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .paymentSheet
        settings.integrationType = .normal
        settings.customerMode = .new
        settings.applePayEnabled = .off
        settings.apmsEnabled = .off
        settings.linkEnabled = .off
        settings.requireCVCRecollection = .on

        loadPlayground(app, settings)

        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()

        try! fillCardData(app)
    }
}

extension XCUIElement {
    func clearText() {
        guard let stringValue = value as? String, !stringValue.isEmpty else {
            return
        }

        // offset tap location a bit so cursor is at end of string
        let offsetTapLocation = coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.6))
        offsetTapLocation.tap()

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
    }
}

extension XCUIElement {
    /// Scrolls a picker wheel up by one option.
    func selectNextOption() {
        let startCoord = self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let endCoord = startCoord.withOffset(CGVector(dx: 0.0, dy: 30.0)) // 30pts = height of picker item
        endCoord.tap()
    }
}

extension XCUIApplication {
    func tapCoordinate(at point: CGPoint) {
        let normalized = coordinate(withNormalizedOffset: .zero)
        let offset = CGVector(dx: point.x, dy: point.y)
        let coordinate = normalized.withOffset(offset)
        coordinate.tap()
    }
}

extension Dictionary {
    subscript(string key: Key) -> String? {
        return self[key] as? String
    }
}
