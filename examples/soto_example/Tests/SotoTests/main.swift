#if os(Linux)
    import XCTest

    XCTMain([
        testCase(SotoTests.allTests),
    ])
#endif
