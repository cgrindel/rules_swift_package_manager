import GreetingsFramework

public struct World {
    public init() {}
    public var name = "World"
}

extension World: NameProvider {}
