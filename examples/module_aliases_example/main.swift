import GameUtils // swift-game's `Utils` module, renamed via `moduleAliases` in Package.swift.
import Logging // The first-party module defined in this example.
import SwiftLog // swift-log's `Logging` module, renamed via `moduleAliases` in Package.swift.
import Utils // swift-draw's `Utils` module, which keeps its original name.

let firstPartyLogger = Logging.Logger(label: "first-party")
print(firstPartyLogger.log("Hello from the first-party Logging module!"))

var swiftLogLogger = SwiftLog.Logger(label: "swift-log")
swiftLogLogger.info("Hello from swift-log, compiled as the SwiftLog module!")

print(GameUtils.GameGreeting().message)
print(Utils.DrawGreeting().message)
