import Foundation
import SimpleCore

@objc(OIFooSwiftVersionInfo)
public class FooSwiftVersionInfo: NSObject {
    @objc(myVersion) public func version() -> String {
        let verInfo = VersionInfo()
        return verInfo.version
    }
}
