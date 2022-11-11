package gazelle

import (
	"log"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/language"
	"golang.org/x/exp/slices"
)

func (l *swiftLang) GenerateRules(args language.GenerateArgs) language.GenerateResult {
	result := language.GenerateResult{}

	// DEBUG BEGIN
	log.Printf("*** CHUCK: GenerateRules args: %+#v", args)
	// DEBUG END

	// Be sure to use args.Rel when determining whether this is a module directory. We do not want
	// to check directories that are outside of the workspace.
	if isModuleRootDir(args.Rel) == noResult {
		return result
	}

	// Recursively, find all of the Swift files under this directory
	// Concatenate with the generated files.
	swiftFiles := findSwiftFiles(args.Dir)
	allFiles := append(swiftFiles, args.GenFiles...)
	slices.Sort(allFiles)

	// DEBUG BEGIN
	log.Printf("*** CHUCK allFiles: ")
	for idx, item := range allFiles {
		log.Printf("*** CHUCK %d: %+#v", idx, item)
	}
	// DEBUG END

	return result
}

func findSwiftFiles(dir string) []string {
	pattern := filepath.Join(dir, "**", "*.swift")
	// DEBUG BEGIN
	log.Printf("*** CHUCK: findSwiftFiles pattern: %+#v", pattern)
	// DEBUG END
	absSwiftFiles, err := filepath.Glob(pattern)
	if err != nil {
		log.Fatal("failed finding Swift files", err)

	}
	swiftFiles := make([]string, len(absSwiftFiles))
	for idx, swf := range absSwiftFiles {
		swiftFiles[idx], err = filepath.Rel(dir, swf)
		if err != nil {
			log.Fatalf("failed calculating the relative path for %s. %s", swf, err)
		}
	}
	return swiftFiles
}

var moduleParentDirNames = []string{
	"Sources",
	"Source",
	"Tests",
}

type yesNoMaybe int

const (
	// The
	noResult yesNoMaybe = iota
	yesResult
	maybeResult
)

func isModuleRootDir(path string) yesNoMaybe {
	// If we do not see the module parent in the path, we could be a Swift module
	moduleParentDistance := distanceFromPath(moduleParentDirNames, path, 0)
	switch moduleParentDistance {
	case -1:
		return maybeResult
	case 1:
		return yesResult
	default:
		return noResult
	}
}

func distanceFromPath(values []string, path string, distance int) int {
	if path == "" {
		return -1
	}
	basename := filepath.Base(path)
	if slices.Contains(values, basename) {
		return distance
	}
	dir := filepath.Dir(path)
	return distanceFromPath(values, dir, distance+1)
}
