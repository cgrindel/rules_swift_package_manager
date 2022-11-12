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
		IsTest: strings.HasPrefix(rel, "_test.swift"),
	}

	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		for _, match := range swiftRe.FindAllSubmatch(scanner.Bytes(), -1) {
			switch {
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
	importStmt := `^\s*\bimport\s*(?P<import>` + ident + `)\b`
	mainAnnotation := `^\s*(?P<mainanno>@main\b)`
	mainFnDecl := `(?P<mainfn>\bstatic\s+func\s+main\b)`
	swiftReSrc := strings.Join([]string{importStmt, mainAnnotation, mainFnDecl}, "|")
	return regexp.MustCompile(swiftReSrc)
}

const (
	// The subexpression index values are derived from the order in the swiftReSrc expression.
	importReSubexpIdx         = 1
	mainAnnotationReSubexpIdx = 2
	mainFnReSubexpIdx         = 3
)
