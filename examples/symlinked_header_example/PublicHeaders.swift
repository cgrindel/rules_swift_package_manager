import AblyDeltaCodec
import Foundation
import msgpack

public func packedDictionaryIsDelta() -> Bool {
    guard let packed = (["key": "value"] as NSDictionary).messagePack() else {
        return false
    }
    return ARTDeltaCodec.isDelta(packed)
}
