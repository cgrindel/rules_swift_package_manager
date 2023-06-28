package swiftpkg

import (
	"bufio"
	"io"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// SwiftFileInfo represents source file information that is pertinent for Swift build file generation.
type SwiftFileInfo struct {
	Rel              string
	Abs              string
	Imports          []string
	IsTest           bool
	ContainsMain     bool
	HasObjcDirective bool
}

// NewSwiftFileInfoFromReader returns file info for a source file.
func NewSwiftFileInfoFromReader(rel, abs string, reader io.Reader) *SwiftFileInfo {
	fi := SwiftFileInfo{
		Rel:    rel,
		Abs:    abs,
		IsTest: testSuffixes.HasSuffix(rel) || TestDirSuffixes.IsUnderDirWithSuffix(rel),
		// There are several ways to detect a main.
		// 1. A file named "main.swift"
		// 2. @main annotation
		// 3. public static func main()
		ContainsMain: filepath.Base(rel) == "main.swift",
	}

	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		for _, match := range swiftRe.FindAllSubmatch(scanner.Bytes(), -1) {
			switch {
			case match[commentLineReSubexpIdx] != nil:
				// Found a comment line; do not try and match anything else
			case match[importReSubexpIdx] != nil:
				fi.Imports = append(fi.Imports, string(match[importReSubexpIdx]))
			case match[mainAnnotationReSubexpIdx] != nil:
				fi.ContainsMain = true
			case match[mainFnReSubexpIdx] != nil:
				fi.ContainsMain = true
			case match[objcDirReSubexpIdx] != nil:
				fi.HasObjcDirective = true
			}
		}
	}
	sort.Strings(fi.Imports)

	return &fi
}

// NewSwiftFileInfoFromSrc returns file info for source file's contents as a string.
func NewSwiftFileInfoFromSrc(rel, abs, src string) *SwiftFileInfo {
	return NewSwiftFileInfoFromReader(rel, abs, strings.NewReader(src))
}

// NewSwiftFileInfoFromPath returns file info from a filesystem path.
func NewSwiftFileInfoFromPath(rel, abs string) (*SwiftFileInfo, error) {
	file, err := os.Open(abs)
	if err != nil {
		return nil, err
	}
	return NewSwiftFileInfoFromReader(rel, abs, file), nil
}

// NewSwiftFileInfosFromRelPaths returns a slice of file information for the source files in a directory.
func NewSwiftFileInfosFromRelPaths(dir string, srcs []string) []*SwiftFileInfo {
	fileInfos := make([]*SwiftFileInfo, len(srcs))
	for idx, src := range srcs {
		abs := filepath.Join(dir, src)
		fi, err := NewSwiftFileInfoFromPath(src, abs)
		if err != nil {
			log.Printf("failed to create swift.SwiftFileInfo for %s. %s", abs, err)
			continue
		}
		fileInfos[idx] = fi
	}
	return fileInfos
}

var swiftRe = buildSwiftRegexp()

func buildSwiftRegexp() *regexp.Regexp {
	ident := `[A-Za-z][A-Za-z0-9_]*`
	commentLine := `^\s*(?P<commentline>//.*)`
	importStmt := `\bimport\s*(?P<import>` + ident + `)\b`
	mainAnnotation := `^\s*(?P<mainanno>@main\b)`
	mainFnDecl := `(?P<mainfn>\bstatic\s+func\s+main\b)`
	objcDirective := `(?P<objcdir>@objc\b)`
	swiftReSrc := strings.Join(
		[]string{commentLine, importStmt, mainAnnotation, mainFnDecl, objcDirective},
		"|",
	)
	return regexp.MustCompile(swiftReSrc)
}

const (
	// The subexpression index values are derived from the order in the swiftReSrc expression.
	commentLineReSubexpIdx    = 1
	importReSubexpIdx         = 2
	mainAnnotationReSubexpIdx = 3
	mainFnReSubexpIdx         = 4
	objcDirReSubexpIdx        = 5
)

type fileSuffixes []string

func (fs fileSuffixes) HasSuffix(path string) bool {
	for _, suffix := range fs {
		if strings.HasSuffix(path, suffix) {
			return true
		}
	}
	return false
}

var testSuffixes = fileSuffixes{"Tests.swift", "Test.swift"}

// DirSuffixes provides a means for testing a path having one of the listed suffixes.
type DirSuffixes []string

// HasSuffix checks if the path has one of the suffixes.
func (ds DirSuffixes) HasSuffix(path string) bool {
	for _, suffix := range ds {
		if strings.HasSuffix(path, suffix) {
			return true
		}
	}
	return false
}

// IsUnderDirWithSuffix checks if the path has a directory that includes one of the suffixes.
func (ds DirSuffixes) IsUnderDirWithSuffix(path string) bool {
	if path == "." || path == "" || path == "/" {
		return false
	}
	dir := filepath.Dir(path)
	if ds.HasSuffix(dir) {
		return true
	}
	return ds.IsUnderDirWithSuffix(dir)
}

// TestDirSuffixes lists the suffixes used for Swift test directories.
var TestDirSuffixes = DirSuffixes{"Tests", "Test"}

// SwiftFileInfos represents a collection of SwiftFileInfo instances.
type SwiftFileInfos []*SwiftFileInfo

// RequiresModulemap determines whether a modulemap target will be generated for this target.
func (sfis SwiftFileInfos) RequiresModulemap() bool {
	for _, sfi := range sfis {
		if sfi.HasObjcDirective {
			return true
		}
	}
	return false
}
