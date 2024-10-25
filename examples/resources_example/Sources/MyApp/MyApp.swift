import CoolUI
import EmbraceIO
import GoogleSignInSwift
import IterableSDK
import MoreCoolUI
import RecaptchaEnterprise
import SDWebImageSwiftUI
import SwiftUI

@main
struct MyApp: App {
    init() {
        do {
            try Embrace
                .setup(options: embraceOptions)
                .start()
        } catch let err {
            print("Error starting Embrace \(err.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            VStack {
                CoolStuff.title()
                CoolStuff.image().resizable()
                MoreCoolStuff.title()
                MoreCoolStuff.image().resizable()
                WebImage(url: URL(string: "https://nokiatech.github.io/heif/content/images/ski_jump_1440x960.heic"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                // Ensure that Google sign-in can find its resources.
                GoogleSignInButton {
                    print("Signing in")
                }
            }
        }
    }
}
