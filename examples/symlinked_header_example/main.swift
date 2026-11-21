import Ably
import Foundation
import PublicHeadersObjc
import PublicHeadersSwift

let options = ARTClientOptions(key: "example:key")
print("Ably client options for key \(options.key ?? "")")
let packed = PublicHeadersPackDictionary(["key": "value"]) ?? Data()
print("Packed \(packed.count) bytes; delta: \(PublicHeadersIsDelta(packed)), \(packedDictionaryIsDelta())")
