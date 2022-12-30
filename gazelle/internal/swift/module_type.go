package swift

type ModuleType int

const (
	UnknownModuleType ModuleType = iota
	LibraryModuleType
	BinaryModuleType
	TestModuleType
)
