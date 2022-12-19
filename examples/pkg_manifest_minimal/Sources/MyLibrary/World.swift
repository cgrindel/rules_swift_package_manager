import GreetingsFramework

public struct World {
    public init() {}
}

extension World: NameProvider {
    public var name = "World"
}
