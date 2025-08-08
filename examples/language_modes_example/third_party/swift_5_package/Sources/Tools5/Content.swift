// Return what language mode was used to compile this package
public func getLanguageMode() -> Int {
    #if swift(>=6) 
    return 6
    #else
    return 5
    #endif
}
