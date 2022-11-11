package gazelle

import (
	"log"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/language"
	"golang.org/x/exp/slices"
)

func (l *swiftLang) GenerateRules(args language.GenerateArgs) language.GenerateResult {
	result := language.GenerateResult{}

	swiftFiles := collectSwiftFiles(append(args.RegularFiles, args.GenFiles...))

	// Be sure to use args.Rel when determining whether this is a module directory. We do not want
	// to check directories that are outside of the workspace.
	moduleRootDir := getModuleRootDir(args.Rel)
	if args.Rel != moduleRootDir {
		dirRelToModuleRoot, err := filepath.Rel(moduleRootDir, args.Rel)
		if err != nil {
			log.Fatalf("failed to find the relative path for %s from %s. %s", args.Rel, moduleRootDir, err)
		}
		swiftFilesWithParentDir := make([]string, len(swiftFiles))
		for idx, swf := range swiftFiles {
			swiftFilesWithParentDir[idx] = filepath.Join(dirRelToModuleRoot, swf)
		}
		appendModuleFilesInSubdirs(moduleRootDir, swiftFilesWithParentDir)
		return result
	}

	// Retrieve any Swift files that have already been found
	swiftFiles = append(swiftFiles, getModuleFilesInSubdirs(moduleRootDir)...)

	// DEBUG BEGIN
	log.Printf("*** CHUCK: GenerateRules args.Rel: %+#v", args.Rel)
	log.Printf("*** CHUCK: GenerateRules swiftFiles: ")
	for idx, item := range swiftFiles {
		log.Printf("*** CHUCK %d: %+#v", idx, item)
	}
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
	moduleParentDistance := distanceFromPath(moduleParentDirNames, path, 0)
	switch moduleParentDistance {
	case -1:
		// We did not find a module parent. So, we could be non-standard Swift directory.
		return path
	case 1:
		// We are a bonafide module root.
		return path
	default:
		return getPathAtDistance(path, moduleParentDistance-1)
	}
}

func getPathAtDistance(path string, distance int) string {
	if path == "" || distance <= 0 {
		return path
	}
	parent := filepath.Dir(path)
	return getPathAtDistance(parent, distance-1)
}

// func getPathFromDistance(path string, distance int) string {
// 	if distance <= 0 {
// 		return ""
// 	}
// 	curPath := path
// 	keep := make([]string, distance)
// 	for idx := distance - 1; idx >= 0; idx-- {
// 		keep[idx] = filepath.Base(curPath)
// 		curPath = filepath.Dir(curPath)
// 	}
// 	result := ""
// 	for _, part := range keep {
// 		result = filepath.Join(result, part)
// 	}
// 	return result
// }

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
