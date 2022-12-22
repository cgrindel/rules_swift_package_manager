import Fluent
import Foundation

public final class Foo: Model {
    public static let schema = "foos"

    @ID(key: .id)
    public var id: UUID?

    @Timestamp(key: "created_at", on: .create, format: .iso8601(withMilliseconds: true))
    public var createdAt: Date?

    @Field(key: "name")
    public var name: String?

    public init() {}
}
