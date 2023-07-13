import Markdown
import NIO

class MarkdownExample {
    func test_parsing() throws {
        let source = "This is a markup *document*."
        let document = Document(parsing: source)
        print(document)
    }
}
