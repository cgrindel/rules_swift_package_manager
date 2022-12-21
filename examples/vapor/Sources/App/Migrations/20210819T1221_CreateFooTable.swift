import Fluent

public struct CreateFooTable: Migration {
    let foosName = "foos"

    public init() {}

    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(foosName)
            .id()
            .field("name", .string, .required)
            .field("created_at", .string, .required)
            .create()
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(foosName).delete()
    }
}
