import CoolUI
import MoreCoolUI
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                CoolStuff.title()
                CoolStuff.image().resizable()
                MoreCoolStuff.title()
                MoreCoolStuff.image().resizable()
            }
        }
    }
}
