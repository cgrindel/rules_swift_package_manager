import libwebp
import Logging
import PorterStemmer2

let logger = Logger(label: "com.example.main")
logger.info("Hello World!")

let webpVersion = WebPGetDecoderVersion()
logger.info("WebP version: \(webpVersion)")

guard let stemmer = PorterStemmer(withLanguage: .English) else {
    logger.error("Failed to create stemmer.")
    exit(1)
}

logger.info("Stemmer: \(stemmer.stem("running"))")
