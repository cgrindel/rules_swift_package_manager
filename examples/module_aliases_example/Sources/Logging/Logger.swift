/// A first-party module named `Logging` — the same module name that
/// apple/swift-log uses. Without the module alias declared in Package.swift,
/// this module and swift-log's `Logging` module could not coexist in the same
/// build under rules_swift's `swift.use_explicit_swift_module_map` feature.
public struct Logger {
    public let label: String

    public init(label: String) {
        self.label = label
    }

    public func log(_ message: String) -> String {
        "[\(label)] \(message)"
    }
}
