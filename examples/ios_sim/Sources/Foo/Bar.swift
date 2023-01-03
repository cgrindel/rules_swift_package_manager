import NIO

public struct Bar {
    var name: String

    public init(name: String) {
        self.name = name
    }

    public func sayHello(eventLoop: EventLoop) -> EventLoopFuture<String> {
        return eventLoop.makeSucceededFuture("Hello, \(name)")
    }
}
