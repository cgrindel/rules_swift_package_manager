public struct MorningGreeting {
    public init() {}
}

extension MorningGreeting: GreetingProvider {
    public var greeting: String {
        return "Good morning"
    }
}
