import Markdown
import NIO

class MarkdownExample {
    func test_parsing() throws {
        let source = "This is a markup *document*."
        let document = Document(parsing: source)
        document.isEmpty
        print(document)
    }
}
