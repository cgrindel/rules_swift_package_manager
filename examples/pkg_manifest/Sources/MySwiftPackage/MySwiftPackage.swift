import ArgumentParser

@main
struct MySwiftPackage: AsyncParsableCommand {
    public private(set) var text = "Hello, World!"

    mutating func main() async throws {
        print(MySwiftPackage().text)
    }
}
