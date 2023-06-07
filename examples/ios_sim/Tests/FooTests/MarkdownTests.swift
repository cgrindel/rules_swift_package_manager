@testable import Markdown
import XCTest

class MarkdownTests: XCTestCase {
    func test_parsing() throws {
        let source = "This is a markup *document*."
        let document = Document(parsing: source)
        // XCTAssertNotEqual(document.debugDescription(), "")
        XCTAssertEqual(document.debugDescription(), "")
    }
}
