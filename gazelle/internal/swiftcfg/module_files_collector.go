package swiftcfg

type ModuleFilesCollector map[string][]string

func NewModuleFilesCollector() ModuleFilesCollector {
	return make(ModuleFilesCollector)
}

func (mfc ModuleFilesCollector) AppendModuleFiles(moduleDir string, paths []string) {
	var existingPaths []string
	if eps, ok := mfc[moduleDir]; ok {
		existingPaths = eps
	}
	existingPaths = append(existingPaths, paths...)
	mfc[moduleDir] = existingPaths
}

func (mfc ModuleFilesCollector) GetModuleFiles(moduleDir string) []string {
	var moduleSwiftFiles []string
	if eps, ok := mfc[moduleDir]; ok {
		moduleSwiftFiles = eps
	}
	return moduleSwiftFiles
}
