import Shake
import SwiftUI

@main
struct ShakeIOSExampleApp: App {
    init() {
        Shake.start(apiKey: "app-api-key")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
