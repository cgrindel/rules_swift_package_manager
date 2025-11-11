import App
import Logging

let logger = Logger(label: "com.example.main")
logger.info("Starting application...")

let app = Application([:])
defer { app.shutdown() }
try configure(app)
try app.run()
