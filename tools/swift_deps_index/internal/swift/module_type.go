package swift

// A ModuleType is an enum for the type of Swift module.
type ModuleType int

const (
	UnknownModuleType ModuleType = iota
	LibraryModuleType
	BinaryModuleType
	TestModuleType
)
