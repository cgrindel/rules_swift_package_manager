package swift

import "github.com/cgrindel/rules_swift_package_manager/gazelle/internal/pathdistance"

var moduleParentDirNames = []string{
	"Sources",
	"Source",
	"Tests",
}

// ModuleDir returns the module root directory.
func ModuleDir(path string) string {
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
