package swiftcfg

// A ModuleFilesCollector organizes source files by the directory where the module/target should be
// defined.
type ModuleFilesCollector map[string][]string

func NewModuleFilesCollector() ModuleFilesCollector {
	return make(ModuleFilesCollector)
}

// AppendModuleFiles adds the paths under the specified module directory.
func (mfc ModuleFilesCollector) AppendModuleFiles(moduleDir string, paths []string) {
	var existingPaths []string
	if eps, ok := mfc[moduleDir]; ok {
		existingPaths = eps
	}
	existingPaths = append(existingPaths, paths...)
	mfc[moduleDir] = existingPaths
}

// GetModuleFiles returns the files for a module directory.
func (mfc ModuleFilesCollector) GetModuleFiles(moduleDir string) []string {
	var moduleSwiftFiles []string
	if eps, ok := mfc[moduleDir]; ok {
		moduleSwiftFiles = eps
	}
	return moduleSwiftFiles
}
