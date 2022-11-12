package swift_test

import (
	"path/filepath"
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

const fileInfoRel = "Foo/Hello.swift"
const fileInfoAbs = "/path/to/workspace/Foo/Hello.swift"

func TestNewFileInfoFromSrc(t *testing.T) {
	t.Run("main function without imports", func(t *testing.T) {
		actual := swift.NewFileInfoFromSrc(
			fileInfoRel, fileInfoAbs, mainFnWithoutImports)
		expected := &swift.FileInfo{
			Rel:          fileInfoRel,
			Abs:          fileInfoAbs,
			ContainsMain: true,
		}
		assert.Equal(t, expected, actual)
	})
	t.Run("main annotation with imports", func(t *testing.T) {
		actual := swift.NewFileInfoFromSrc(
			fileInfoRel, fileInfoAbs, mainAnnotationWithImports)
		expected := &swift.FileInfo{
			Rel:          fileInfoRel,
			Abs:          fileInfoAbs,
			Imports:      []string{"ArgumentParser", "Foundation"},
			ContainsMain: true,
		}
		assert.Equal(t, expected, actual)
	})
	t.Run("test file", func(t *testing.T) {
		rel := "FooTests/HelloTests.swift"
		abs := filepath.Join("Tests", rel)
		actual := swift.NewFileInfoFromSrc(rel, abs, testFile)
		expected := &swift.FileInfo{
			Rel:          rel,
			Abs:          abs,
			Imports:      []string{"DateUtils", "XCTest"},
			IsTest:       true,
			ContainsMain: false,
		}
		assert.Equal(t, expected, actual)
	})
}

const mainFnWithoutImports = `
@main
public struct Hello {
    public private(set) var text = "Hello, World!"

    public static func main() {
        print(Hello().text)
    }
}
`

const mainAnnotationWithImports = `
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

const testFile = `
@testable import DateUtils
import XCTest

// The following should not be seen.
// @main

class DateISOTests: XCTestCase {
}
`
