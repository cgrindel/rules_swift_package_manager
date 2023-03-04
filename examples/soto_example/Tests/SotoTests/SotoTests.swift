@testable import SotoS3
import XCTest

class SotoTests: XCTestCase {
    func testSomething() {
        let bucketName = "soto-getting-started-bucket"
        let createBucketRequest = S3.CreateBucketRequest(bucket: bucketName)
        XCTAssertEqual(createBucketRequest.bucket, bucketName)
    }

    static var allTests = [
        ("testSomething", testSomething),
    ]
}
