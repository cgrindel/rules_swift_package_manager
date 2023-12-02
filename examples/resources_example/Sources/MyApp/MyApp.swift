import CoolUI
import GoogleSignInSwift
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
                Text("PocketSVG Image")
                SVGImageWrapper(resource: "tiger")
                    .frame(width: 100, height: 100)
                // Ensure that Google sign-in can find its resources.
                GoogleSignInButton {
                    print("Signing in")
                }
            }
        }
    }
}
