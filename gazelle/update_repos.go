package gazelle

import (
	"log"

	"github.com/bazelbuild/bazel-gazelle/language"
)

// language.RepoImporter Implementation

func (*swiftLang) CanImport(path string) bool {
	// DEBUG BEGIN
	log.Printf("*** CHUCK: CanImport path: %+#v", path)
	// DEBUG END
	return false
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
