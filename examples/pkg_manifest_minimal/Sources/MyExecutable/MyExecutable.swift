import ArgumentParser
import FarewellFramework
import GreetingsFramework
import MyLibrary
import NotThatAmazingModule

@main
struct MyExecutable: AsyncParsableCommand {
    mutating func run() async throws {
        let namedGreeting = NamedGreeting(MorningGreeting(), World())
        print(namedGreeting.value)

        let complexClass = ComplexClass(name: "Olivia", age: 30, favoriteColors: ["blue"])
        complexClass.greet()
        let farewellMessage = FarewellFramework.myclang_get_farewell_message(MYCLANG_FAREWELL_GOODBYE)
        print(String(cString: farewellMessage!))
    }
}
