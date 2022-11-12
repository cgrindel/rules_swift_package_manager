package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

const fileInfoRel = "Foo/Hello.swift"
const fileInfoAbs = "/path/to/workspace/Foo/Hello.swift"

func TestNewFileInfoFromSrc(t *testing.T) {
	t.Run("no imports", func(t *testing.T) {
		actual := swift.NewFileInfoFromSrc(
			fileInfoRel, fileInfoAbs, srcWithoutImports)
		expected := &swift.FileInfo{
			Rel: fileInfoRel,
			Abs: fileInfoAbs,
		}
		assert.Equal(t, expected, actual)
	})
	t.Run("with imports", func(t *testing.T) {
		actual := swift.NewFileInfoFromSrc(
			fileInfoRel, fileInfoAbs, srcWithImports)
		expected := &swift.FileInfo{
			Rel:     fileInfoRel,
			Abs:     fileInfoAbs,
			Imports: []string{"ArgumentParser", "Foundation"},
		}
		assert.Equal(t, expected, actual)
	})
}

const srcWithoutImports = `
@main
public struct Hello {
    public private(set) var text = "Hello, World!"

    public static func main() {
        print(Hello().text)
    }
}
`

const srcWithImports = `
// Intentionally not sorted to ensure that FileInfo imports is sorted
import Foundation
import ArgumentParser

// The following should not be found
// import Foo

@main
@available(macOS 10.15, *)
struct CountLines: AsyncParsableCommand {
    @Argument(
        help: "A file to count lines in. If omitted, counts the lines of stdin.",
        completion: .file(), transform: URL.init(fileURLWithPath:))
    var inputFile: URL? = nil
    
    @Option(help: "Only count lines with this prefix.")
    var prefix: String? = nil
    
    @Flag(help: "Include extra information in the output.")
    var verbose = false
}
`
