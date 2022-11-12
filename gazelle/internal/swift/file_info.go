package swift

import (
	"log"
	"regexp"
	"sort"
	"strings"
)

type FileInfo struct {
	Rel     string
	Abs     string
	Imports []string
}

func NewFileInfoFromSrc(rel, abs string, content []byte) *FileInfo {
	fi := FileInfo{
		Rel: rel,
		Abs: abs,
	}

	for _, match := range swiftRe.FindAllSubmatch(content, -1) {
		switch {
		case match[importReSubexpIdx] != nil:
			fi.Imports = append(fi.Imports, string(match[importReSubexpIdx]))
		}
	}
	sort.Strings(fi.Imports)

	return &fi
}

var swiftRe = buildSwiftRegexp()

func buildSwiftRegexp() *regexp.Regexp {
	ident := `[A-Za-z][A-Za-z0-9_]*`
	// importStmt := `^\s*\bimport\s*(?P<import>` + ident + `)\s*`
	importStmt := `\s*\bimport\s*(?P<import>` + ident + `)\s*`
	swiftReSrc := strings.Join([]string{importStmt}, "|")
	// DEBUG BEGIN
	log.Printf("*** CHUCK:  swiftReSrc: %+#v", swiftReSrc)
	// DEBUG END
	return regexp.MustCompile(swiftReSrc)
}

const (
	// The subexpression index values are derived from the order in the swiftReSrc expression.
	importReSubexpIdx = 1
)
