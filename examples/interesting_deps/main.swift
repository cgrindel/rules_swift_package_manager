import CocoaLumberjack
import CocoaLumberjackSwiftLogBackend
import FooSwift
import GEOSwift
import libwebp
import Logging
import OpenCombine

// Configure DDLog to be the backend for the swift-log.
DDLog.add(DDTTYLogger.sharedInstance!)
LoggingSystem.bootstrapWithCocoaLumberjack()

let logger = Logger(label: "com.example.main")
logger.info("Hello World!")

let webpVersion = WebPGetDecoderVersion()
logger.info("WebP version: \(webpVersion)")

fooSwift()
