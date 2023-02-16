import SimpleCore

@main
enum PrintVersion {
    static func main() {
        let verInfo = VersionInfo()
        print(verInfo.version)
    }
}
