public struct EveningGreeting {
    public init() {}
}

extension EveningGreeting: GreetingProvider {
    public var greeting: String {
        return "Good evening"
    }
}
