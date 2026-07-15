// swift-log's module, renamed to `SwiftLog` by the root manifest. swift-game
// keeps importing the original `Logging` name; this only compiles because
// swift-game, as a direct dependent of swift-log, receives the propagated
// `-module-alias Logging=SwiftLog` flag.
import Logging

public let gameName = "swift-game"

public struct GameGreeting {
    public init() {}

    public var message: String {
        // Reference swift-log's `Logger` (imported as `Logging`) so the
        // propagated `-module-alias` flag is exercised at compile time.
        let logger = Logger(label: "swift-game")
        _ = logger

        // Self-qualified with the original module name to exercise the
        // `-module-alias` flag that the renamed module itself compiles with.
        return Utils.gameName + " says hello via its aliased GameUtils module!"
    }
}
