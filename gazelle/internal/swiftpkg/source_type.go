package swiftpkg

import (
	"encoding/json"
	"fmt"
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
}

func NewSourceType(moduleType string, srcPaths []string) SourceType {
	// TODO(chuck): IMPLEMENT ME!
	return UnknownSourceType
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
