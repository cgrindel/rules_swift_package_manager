package gazelle

import (
	"log"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/language"
)

// language.RepoImporter Implementation

func (*swiftLang) CanImport(path string) bool {
	base := filepath.Base(path)
	return base == "Package.resolved"
}

func (*swiftLang) ImportRepos(args language.ImportReposArgs) language.ImportReposResult {
	result := language.ImportReposResult{}
	// DEBUG BEGIN
	log.Printf("*** CHUCK: ImportRepos args: %+#v", args)
	// DEBUG END
	return result
}

// language.RepoUpdate Implementation

// Update repository rules that provide named libraries
func (*swiftLang) UpdateRepos(args language.UpdateReposArgs) language.UpdateReposResult {
	result := language.UpdateReposResult{}
	// DEBUG BEGIN
	log.Printf("*** CHUCK: UpdateRepos args: %+#v", args)
	// DEBUG END
	return result
}
