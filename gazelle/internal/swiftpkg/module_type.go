package swiftpkg

// A ModuleType is an enum for the Swift manifest module type.
type ModuleType int

const (
	UnknownModuleType ModuleType = iota
	SwiftModuleType
	ClangModuleType
	BinaryModuleType
	PluginModuleType
)

var moduleTypeIDToStr map[ModuleType]string

var moduleTypeStrToID map[string]ModuleType

func init() {
	moduleTypeIDToStr = map[ModuleType]string{
		UnknownModuleType: "unknown",
		SwiftModuleType:   "SwiftTarget",
		ClangModuleType:   "ClangTarget",
		BinaryModuleType:  "BinaryTarget",
		PluginModuleType:  "PluginTarget",
	}
	moduleTypeStrToID = make(map[string]ModuleType)
	for id, str := range moduleTypeIDToStr {
		moduleTypeStrToID[str] = id
	}
}

// NewModuleType returns the module type from the provided string value.
func NewModuleType(str string) ModuleType {
	if id, ok := moduleTypeStrToID[str]; ok {
		return id
	}
	return UnknownModuleType
}
