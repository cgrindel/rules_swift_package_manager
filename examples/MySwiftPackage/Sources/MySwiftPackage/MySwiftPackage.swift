@main
public struct MySwiftPackage {
    public private(set) var text = "Hello, World!"

    public static func main() {
        print(MySwiftPackage().text)
    }
}
