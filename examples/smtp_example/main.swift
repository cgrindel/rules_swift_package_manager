import SwiftSMTP

let configuration = Configuration.fromEnvironment()
print(configuration.server.hostname)
