import App_Models
import Vapor

enum AppError: Error {
    case missingName
    case notFound
}

func routes(_ app: Application) throws {
    app.get { _ in
        "It works!"
    }

    app.get("hello", ":name") { req -> EventLoopFuture<String> in
        guard let name = req.parameters.get("name") else {
            throw AppError.missingName
        }

        // Create a Foo record and read it back before responding
        let foo = Foo()
        foo.name = name
        return foo.save(on: app.db).flatMap {
            Foo.find(foo.id, on: app.db)
        }.flatMap { optFoo -> EventLoopFuture<Foo> in
            let eventLoop = app.db.eventLoop
            guard let newFoo = optFoo else {
                return eventLoop.makeFailedFuture(AppError.notFound)
            }
            return eventLoop.makeSucceededFuture(newFoo)
        }.map { newFoo in
            "Hello, \(newFoo.name!)!"
        }
    }
}
