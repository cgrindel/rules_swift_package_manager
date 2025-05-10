import KSCrashInstallations
import SwiftUI

@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      Text("Hello KSCrash")
        .onAppear {
          let installation = CrashInstallationStandard.shared
          installation.url = URL(string: "http://put.your.url.here")!

          let config = KSCrashConfiguration()
          config.monitors = [.machException, .signal]
          try! installation.install(with: config)

          installation.addConditionalAlert(
            withTitle: "Crash Detected",
            message: "The app crashed last time it was launched. Send a crash report?",
            yesAnswer: "Sure!",
            noAnswer: "No thanks"
          )
        }
    }
  }
}
