package swift

import "github.com/cgrindel/swift_bazel/gazelle/internal/pathdistance"

var moduleParentDirNames = []string{
	"Sources",
	"Source",
	"Tests",
}

// Return the module root directory and the distance to the directory.
func ModuleRootDir(path string) string {
	// If we do not see the module parent in the path, we could be a Swift module
	moduleParentDistance := pathdistance.DistanceFrom(moduleParentDirNames, path)
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
