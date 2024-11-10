package swiftpkg

import (
	"encoding/json"
	"fmt"
	"path/filepath"

	"golang.org/x/exp/slices"
)

// A SourceType is an enum that identifies the type of source files use to implement a Swift
// manifest target.
type SourceType int

const (
	UnknownSourceType SourceType = iota
	SwiftSourceType
	ClangSourceType
	ObjcSourceType
	BinarySourceType
)

var sourceTypeIDToStr map[SourceType]string

var sourceTypeStrToID map[string]SourceType

var objcExtensions []string

func init() {
	sourceTypeIDToStr = map[SourceType]string{
		UnknownSourceType: "unknown",
		SwiftSourceType:   "swift",
		ClangSourceType:   "clang",
		ObjcSourceType:    "objc",
		BinarySourceType:  "binary",
	}
	sourceTypeStrToID = make(map[string]SourceType)
	for id, str := range sourceTypeIDToStr {
		sourceTypeStrToID[str] = id
	}

	objcExtensions = []string{".m", ".mm"}
}

// NewSourceType returns the source type given the module type and a list of the sources for a
// target.
func NewSourceType(moduleType ModuleType, srcPaths []string) SourceType {
	switch moduleType {
	case SwiftModuleType:
		return SwiftSourceType
	case ClangModuleType:
		for _, sp := range srcPaths {
			ext := filepath.Ext(sp)
			if slices.Contains(objcExtensions, ext) {
				return ObjcSourceType
			}
		}
		return ClangSourceType
	case BinaryModuleType:
		return BinarySourceType
	default:
		return UnknownSourceType
	}
}

func (m SourceType) MarshalJSON() ([]byte, error) {
	if str, ok := sourceTypeIDToStr[m]; ok {
		return json.Marshal(str)
	}
	return nil, fmt.Errorf("unrecognized source type value %v", m)
}

func (m *SourceType) UnmarshalJSON(b []byte) error {
	var str string
	if err := json.Unmarshal(b, &str); err != nil {
		return err
	}
	if id, ok := sourceTypeStrToID[str]; ok {
		*m = id
		return nil
	}
	return fmt.Errorf("unrecognized source type string %v", str)
}
