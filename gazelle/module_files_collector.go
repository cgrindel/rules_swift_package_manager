package gazelle

type moduleFilesCollector map[string][]string

func newModuleFilesCollector() moduleFilesCollector {
	return make(moduleFilesCollector)
}

func (mfc moduleFilesCollector) appendModuleFiles(moduleDir string, paths []string) {
	var existingPaths []string
	if eps, ok := mfc[moduleDir]; ok {
		existingPaths = eps
	}
	existingPaths = append(existingPaths, paths...)
	mfc[moduleDir] = existingPaths
}

func (mfc moduleFilesCollector) getModuleFiles(moduleDir string) []string {
	var moduleSwiftFiles []string
	if eps, ok := mfc[moduleDir]; ok {
		moduleSwiftFiles = eps
	}
	return moduleSwiftFiles
}
