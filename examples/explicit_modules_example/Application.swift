import Greeter

@main
enum ExplicitModulesExample {
    static func main() {
        // Exercise Objective-C interop and the generated Bundle.module accessor at runtime.
        let message = greeting()
        precondition(message == "Hello, explicit modules!")
        print(message)
    }
}
