package swiftpkg

import (
	"encoding/json"
	"fmt"
	"log"
	"path/filepath"

	"golang.org/x/exp/slices"
)

type SourceType int

const (
	UnknownSourceType SourceType = iota
	SwiftSourceType
	ClangSourceType
	ObjcSourceType
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
	}
	sourceTypeStrToID = make(map[string]SourceType)
	for id, str := range sourceTypeIDToStr {
		sourceTypeStrToID[str] = id
	}

	objcExtensions = []string{".m", ".mm"}
}

func NewSourceType(moduleType ModuleType, srcPaths []string) SourceType {
	// DEBUG BEGIN
	log.Printf("*** CHUCK: =====")
	log.Printf("*** CHUCK:  moduleType: %+#v", moduleType)
	log.Printf("*** CHUCK:  srcPaths: %+#v", srcPaths)
	// DEBUG END
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
	default:
		return UnknownSourceType
	}
}

func (m *SourceType) MarshalJSON() ([]byte, error) {
	if str, ok := sourceTypeIDToStr[*m]; ok {
		return json.Marshal(&str)
	}
	return nil, fmt.Errorf("unrecognized source type value %v", *m)
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
