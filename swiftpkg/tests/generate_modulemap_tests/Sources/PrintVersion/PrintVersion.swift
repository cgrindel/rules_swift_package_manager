import Foo
import SimpleCore

@main
enum PrintVersion {
    static func main() {
        let verInfo = VersionInfo()
        let fooVerInfo = FooVersionInfo()
        if verInfo.version == fooVerInfo.version {
            print(verInfo.version)
        } else {
            print("Versions do not match")
            print("verInfo: \(verInfo.version), fooVerInfo: \(fooVerInfo.version)")
        }
    }
}
