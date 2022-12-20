public struct NamedGreeting {
    public var greetingProvider: GreetingProvider
    public var nameProvider: NameProvider

    public init(
        _ greetingProvider: GreetingProvider,
        _ nameProvider: NameProvider
    ) {
        self.greetingProvider = greetingProvider
        self.nameProvider = nameProvider
    }

    public var value: String {
        return "\(greetingProvider.greeting), \(nameProvider.name)!"
    }
}
