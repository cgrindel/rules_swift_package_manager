public struct WithName: NameProvider {
    public let name: String

    public init(_ name: String) {
        self.name = name
    }
}
