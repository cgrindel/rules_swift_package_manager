import ArgumentParser
import GreetingsFramework
import MyAmazingModule
import MyLibrary

@main
struct MyExecutable: AsyncParsableCommand {
    mutating func run() async throws {
        let namedGreeting = NamedGreeting(MorningGreeting(), World())
        print(namedGreeting.value)

        let complexClass = ComplexClass(name: "Olivia", age: 30, favoriteColors: ["blue"])
        print(complexClass.greet())
    }
}
