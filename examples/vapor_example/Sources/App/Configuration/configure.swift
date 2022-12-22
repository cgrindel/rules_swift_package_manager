import App_Migrations
import Fluent
import FluentSQLiteDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    app.databases.use(.sqlite(.memory), as: .sqlite)
    app.migrations.add(CreateFooTable(), to: .sqlite)
    try app.autoMigrate().wait()

    // register routes
    try routes(app)
}
