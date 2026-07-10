public let gameName = "swift-game"

public struct GameGreeting {
    public init() {}

    public var message: String {
        // Self-qualified with the original module name to exercise the
        // `-module-alias` flag that the renamed module itself compiles with.
        Utils.gameName + " says hello via its aliased GameUtils module!"
    }
}
