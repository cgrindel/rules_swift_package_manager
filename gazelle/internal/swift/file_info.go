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
	Rel     string
	Abs     string
	Imports []string
}

func NewFileInfoFromReader(rel, abs string, reader io.Reader) *FileInfo {
	fi := FileInfo{
		Rel: rel,
		Abs: abs,
	}

	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		for _, match := range swiftRe.FindAllSubmatch(scanner.Bytes(), -1) {
			switch {
			case match[importReSubexpIdx] != nil:
				fi.Imports = append(fi.Imports, string(match[importReSubexpIdx]))
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
	swiftReSrc := strings.Join([]string{importStmt}, "|")
	return regexp.MustCompile(swiftReSrc)
}

const (
	// The subexpression index values are derived from the order in the swiftReSrc expression.
	importReSubexpIdx = 1
)
