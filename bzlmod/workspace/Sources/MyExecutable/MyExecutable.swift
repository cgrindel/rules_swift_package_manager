import ArgumentParser
import Logging
import MyLibrary
import RegexBuilder

// Because we build on macos/linux this needs to be conditionally imported to test an edge case
#if canImport(os)
    import os
#endif

@main
struct MyExecutable: AsyncParsableCommand {
    struct Plugin {}
    mutating func run() async throws {
        let output = "Hello, \(World().name)!"
        let logger = Logger(label: "com.example.BestExampleApp.main")
        logger.info("\(output)")

        #if canImport(os)
            os_log("This is a debug message.", log: OSLog.default, type: .debug)
        #endif
    }
}
