import ArgumentParser
import Logging
import MyLibrary
import RegexBuilder

@main
struct MyExecutable: AsyncParsableCommand {
    struct Plugin { }
    mutating func run() async throws {
        let output = "Hello, \(World().name)!"
        let logger = Logger(label: "com.example.BestExampleApp.main")
        logger.info("\(output)")
    }
}
