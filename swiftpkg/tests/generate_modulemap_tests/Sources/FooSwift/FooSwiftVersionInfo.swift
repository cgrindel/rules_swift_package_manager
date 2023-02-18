import SimpleCore

public struct FooSwiftVersionInfo {
    public init() {}
}

public extension FooSwiftVersionInfo {
    func version() -> String {
        let verInfo = VersionInfo()
        return verInfo.version
    }
}
