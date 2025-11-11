import App
import Logging
import Vapor

let logger = Logger(label: "com.example.main")
logger.info("Starting application...")

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }
try configure(app)
try app.run()
