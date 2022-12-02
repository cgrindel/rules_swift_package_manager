package gazelle

import (
	"os"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
)

// language.RepoImporter Implementation

func (*swiftLang) CanImport(path string) bool {
	base := filepath.Base(path)
	return base == "Package.resolved"
}

func (*swiftLang) ImportRepos(args language.ImportReposArgs) language.ImportReposResult {
	result := language.ImportReposResult{}

	// Read the Package.resolved file
	b, err := os.ReadFile(args.Path)
	if err != nil {
		result.Error = err
		return result
	}
	pins, err := spreso.NewPinsFromResolvedPackageJSON(b)
	if err != nil {
		result.Error = err
		return result
	}

	result.Gen = make([]*rule.Rule, len(pins))
	for idx, p := range pins {
		result.Gen[idx], err = swift.RepoRuleFromPin(p)
		if err != nil {
			result.Error = err
			return result
		}
	}

	return result
}
