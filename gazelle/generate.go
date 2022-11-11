package gazelle

import (
	"log"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/pathdistance"
	"golang.org/x/exp/slices"
)

func (l *swiftLang) GenerateRules(args language.GenerateArgs) language.GenerateResult {
	result := language.GenerateResult{}

	// Collect Swift files
	swiftFiles := collectSwiftFiles(append(args.RegularFiles, args.GenFiles...))
	if len(swiftFiles) == 0 {
		return result
	}

	// Be sure to use args.Rel when determining whether this is a module directory. We do not want
	// to check directories that are outside of the workspace.
	moduleRootDir := getModuleRootDir(args.Rel)
	if args.Rel != moduleRootDir {
		dirRelToModuleRoot, err := filepath.Rel(moduleRootDir, args.Rel)
		if err != nil {
			log.Fatalf("failed to find the relative path for %s from %s. %s",
				args.Rel, moduleRootDir, err)
		}
		swiftFilesWithParentDir := make([]string, len(swiftFiles))
		for idx, swf := range swiftFiles {
			swiftFilesWithParentDir[idx] = filepath.Join(dirRelToModuleRoot, swf)
		}
		appendModuleFilesInSubdirs(moduleRootDir, swiftFilesWithParentDir)
		return result
	}

	// Retrieve any Swift files that have already been found
	srcs := append(swiftFiles, getModuleFilesInSubdirs(moduleRootDir)...)
	slices.Sort(srcs)

	// TODO(chuck): Add code to check for kind of rule

	// Create a rule
	pkgName := filepath.Base(args.Rel)
	r := rule.NewRule(swiftLibraryRule, pkgName)
	r.SetAttr("srcs", srcs)
	result.Gen = append(result.Gen, r)

	// TODO(chuck): What should I add for imports?
	result.Imports = make([]interface{}, len(result.Gen))
	for idx := range result.Gen {
		result.Imports[idx] = nil
	}

	// DEBUG BEGIN
	log.Printf("*** CHUCK: GenerateRules pkgName: %+#v", pkgName)
	log.Printf("*** CHUCK: GenerateRules result: %+#v", result)
	// DEBUG END

	return result
}

func collectSwiftFiles(paths []string) []string {
	var results []string
	for _, path := range paths {
		ext := filepath.Ext(path)
		if ext == ".swift" {
			results = append(results, path)
		}
	}
	return results
}

var moduleFilesInSubdirs = make(map[string][]string)

func appendModuleFilesInSubdirs(moduleRootDir string, paths []string) {
	var existingPaths []string
	if eps, ok := moduleFilesInSubdirs[moduleRootDir]; ok {
		existingPaths = eps
	}
	existingPaths = append(existingPaths, paths...)
	moduleFilesInSubdirs[moduleRootDir] = existingPaths
}

func getModuleFilesInSubdirs(moduleRootDir string) []string {
	var moduleSwiftFiles []string
	if eps, ok := moduleFilesInSubdirs[moduleRootDir]; ok {
		moduleSwiftFiles = eps
	}
	return moduleSwiftFiles
}

var moduleParentDirNames = []string{
	"Sources",
	"Source",
	"Tests",
}

// Return the module root directory and the distance to the directory.
func getModuleRootDir(path string) string {
	// If we do not see the module parent in the path, we could be a Swift module
	moduleParentDistance := pathdistance.DistanceFrom(moduleParentDirNames, path, 0)
	switch moduleParentDistance {
	case -1:
		// We did not find a module parent. So, we could be non-standard Swift directory.
		return path
	case 1:
		// We are a bonafide module root.
		return path
	default:
		return pathdistance.PathAt(path, moduleParentDistance-1)
	}
}
