#import "PublicHeaders.h"

#import <AblyDeltaCodec/AblyDeltaCodec.h>
#import <msgpack/msgpack.h>

NSData *PublicHeadersPackDictionary(NSDictionary *dictionary) {
    return [dictionary messagePack];
}

BOOL PublicHeadersIsDelta(NSData *data) {
    return [ARTDeltaCodec isDelta:data];
}
