package swift

import (
	"bufio"
	"io"
	"os"
	"regexp"
	"sort"
	"strings"
)

type FileInfo struct {
	Rel          string
	Abs          string
	Imports      []string
	IsTest       bool
	ContainsMain bool
}

func NewFileInfoFromReader(rel, abs string, reader io.Reader) *FileInfo {
	fi := FileInfo{
		Rel:    rel,
		Abs:    abs,
		IsTest: testSuffixes.HasSuffix(rel),
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
			}
		}
	}

	sort.Strings(fi.Imports)

	return &fi
}

func NewFileInfoFromSrc(rel, abs, src string) *FileInfo {
	return NewFileInfoFromReader(rel, abs, strings.NewReader(src))
}

func NewFileInfoFromPath(rel, abs string) (*FileInfo, error) {
	file, err := os.Open(abs)
	if err != nil {
		return nil, err
	}
	return NewFileInfoFromReader(rel, abs, file), nil
}

var swiftRe = buildSwiftRegexp()

func buildSwiftRegexp() *regexp.Regexp {
	ident := `[A-Za-z][A-Za-z0-9_]*`
	commentLine := `^\s*(?P<commentline>//.*)`
	importStmt := `\bimport\s*(?P<import>` + ident + `)\b`
	mainAnnotation := `^\s*(?P<mainanno>@main\b)`
	mainFnDecl := `(?P<mainfn>\bstatic\s+func\s+main\b)`
	swiftReSrc := strings.Join([]string{commentLine, importStmt, mainAnnotation, mainFnDecl}, "|")
	return regexp.MustCompile(swiftReSrc)
}

const (
	// The subexpression index values are derived from the order in the swiftReSrc expression.
	commentLineReSubexpIdx    = 1
	importReSubexpIdx         = 2
	mainAnnotationReSubexpIdx = 3
	mainFnReSubexpIdx         = 4
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
