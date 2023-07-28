import libwebp
import Logging
import PorterStemmer2

let logger = Logger(label: "com.example.main")
logger.info("Hello World!")

let webpVersion = WebPGetDecoderVersion()
logger.info("WebP version: \(webpVersion)")

let stemmer = PorterStemmer(withLanguage: .English)
logger.info("Stemmer: \(stemmer.stem("running"))")
