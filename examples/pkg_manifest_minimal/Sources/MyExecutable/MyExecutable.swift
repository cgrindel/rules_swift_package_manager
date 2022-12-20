import ArgumentParser
import GreetingsFramework
import MyLibrary

@main
struct MyExecutable: AsyncParsableCommand {
    mutating func run() async throws {
        let ng = NamedGreeting(MorningGreeting(), World())
        print(ng.value)
    }
}
