import Foundation
import ObjCGreeter
#if os(iOS)
import UIKit
#endif

public func greeting() -> String {
    let url = Bundle.module.url(forResource: "audience", withExtension: "txt")!
    let audience = try! String(contentsOf: url, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return "\(GreetingPrefix()), \(audience)!"
}
