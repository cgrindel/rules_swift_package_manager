import ArgumentParser
import MyLibrary

@main
struct MyExecutable: AsyncParsableCommand {
    mutating func run() async throws {
        let output = "Hello, \(World())"
        print(output)
    }
}
