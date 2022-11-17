package swift

type ModuleType int

const (
	LibraryModuleType ModuleType = iota
	BinaryModuleType
	TestModuleType
)
