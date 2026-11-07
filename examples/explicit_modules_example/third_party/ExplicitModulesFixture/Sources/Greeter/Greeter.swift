
import Foundation
import ObjCGreeter
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public func greeting() -> String {
    let url = Bundle.module.url(forResource: "audience", withExtension: "txt")!
    let audience = try! String(contentsOf: url, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return "\(GreetingPrefix()), \(audience)!"
}
