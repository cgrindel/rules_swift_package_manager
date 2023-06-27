package swift_test

import (
	"path/filepath"
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swift"
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
	t.Run("main under test directory", func(t *testing.T) {
		rel := "FooTests/main.swift"
		abs := filepath.Join("Tests", rel)
		actual := swift.NewFileInfoFromSrc(rel, abs, mainForTest)
		expected := &swift.FileInfo{
			Rel:          rel,
			Abs:          abs,
			Imports:      []string{"XCTest"},
			IsTest:       true,
			ContainsMain: true,
		}
		assert.Equal(t, expected, actual)
	})
	t.Run("test file", func(t *testing.T) {
		rel := "Foo/Hello.swift"
		abs := filepath.Join("Sources", rel)
		actual := swift.NewFileInfoFromSrc(rel, abs, objcDirective)
		expected := &swift.FileInfo{
			Rel:              rel,
			Abs:              abs,
			Imports:          []string{"Foundation"},
			HasObjcDirective: true,
		}
		assert.Equal(t, expected, actual)
	})
}

func TestDirSuffixes(t *testing.T) {
	actual := swift.TestDirSuffixes.IsUnderDirWithSuffix("Sources/Foo/Bar.swift")
	assert.False(t, actual)

	actual = swift.TestDirSuffixes.IsUnderDirWithSuffix("Tests/FooTests/Bar.swift")
	assert.True(t, actual)

	actual = swift.TestDirSuffixes.IsUnderDirWithSuffix("Tests/FooTests/Chicken/Bar.swift")
	assert.True(t, actual)

	actual = swift.TestDirSuffixes.IsUnderDirWithSuffix("Tests/Bar.swift")
	assert.True(t, actual)
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

const mainForTest = `
#if os(Linux)
import XCTest

XCTMain([
    testCase(AppTests.allTests),
])
#endif
`

const objcDirective = `
#if canImport(Combine) && swift(>=5.0)

  import Foundation

  // Make this class discoverable from Objective-C. Don't instantiate directly.
  @objc(FIRCombineFirestoreLibrary) private class __CombineFirestoreLibrary: NSObject {}

#endif
`
