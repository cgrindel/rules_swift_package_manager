import Foundation
import ObjCGreeter

public func greeting() -> String {
    let url = Bundle.module.url(forResource: "audience", withExtension: "txt")!
    let audience = try! String(contentsOf: url, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return "\(GreetingPrefix()), \(audience)!"
}
