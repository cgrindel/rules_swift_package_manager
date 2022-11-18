package swiftpkg

import "encoding/json"

type Dump struct {
	Name string
	// Dependencies []*DumpDependency
	// Platforms    []*DumpPlatform
	// Products     []*DumpProduct
	// Targets      []*DumpTarget
}

func NewDumpFromJSON(bytes []byte) (*Dump, error) {
	var dump Dump
	err := json.Unmarshal(bytes, &dump)
	if err != nil {
		return nil, err
	}
	return &dump, nil
}
