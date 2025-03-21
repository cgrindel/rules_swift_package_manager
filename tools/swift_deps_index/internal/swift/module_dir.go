package swift

import (
	"path/filepath"
	"strings"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/pathdistance"
)

var moduleParentDirNames = []string{
	"Sources",
	"Source",
	"Tests",
}

// ModuleDir returns the module root directory.
// The configModPaths is a list of relative paths to module directories defined by
// swift_default_module_name directives.
func ModuleDir(configModPaths []string, path string) string {
	// Check if the path is a child of any of the directive paths
	for _, modPath := range configModPaths {
		// If modPath is empty string, then the module is set at the root of the workspace. So
		// everything under the workspace is in this module.
		if modPath == "" || modPath == path {
			return modPath
		}
		modPathWithSlash := modPath + string(filepath.Separator)
		if strings.HasPrefix(path, modPathWithSlash) {
			return modPath
		}
	}

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
