import Foundation
import ComposableArchitecture
import XCTest

@testable import TCAExample

@MainActor
final class AppTests: XCTestCase {

    @MainActor
    func testFeature() async {
        let store = TestStore(initialState: Feature.State()) {
            Feature()
        }

        // Test that tapping on the increment/decrement buttons changes the count
        await store.send(.incrementButtonTapped) {
            $0.count = 1
        }
        await store.send(.decrementButtonTapped) {
            $0.count = 0
        }
    }
}
