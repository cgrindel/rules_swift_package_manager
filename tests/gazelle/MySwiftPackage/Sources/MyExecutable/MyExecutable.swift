import ArgumentParser
import MyLibrary

@main
struct MyExecutable: AsyncParsableCommand {
    mutating func run() async throws {
        print(MyModel().text)
    }
}
