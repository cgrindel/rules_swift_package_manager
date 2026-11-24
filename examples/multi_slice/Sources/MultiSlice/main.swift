import Logging

#if os(Linux)
import SystemPackage
#endif

let logger = Logger(label: "multi_slice")
logger.info("hello from multi_slice")

#if os(Linux)
print(FilePath("/tmp").string)
#endif
