package swiftpkg

import (
	"encoding/json"
	"log"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonmap"
)

func NewDumpFromJSON(bytes []byte) (*Dump, error) {
	var dump Dump
	err := json.Unmarshal(bytes, &dump)
	if err != nil {
		return nil, err
	}
	return &dump, nil
}

// Dump

type Dump struct {
	Name         string
	Dependencies []DumpDependency
	// Platforms    []*DumpPlatform
	// Products     []*DumpProduct
	// Targets      []*DumpTarget
}

// DumpDependency

type DumpDependency struct {
	Name string
	URL  string
	// Requirement DumpDependencyRequirement
}

const dumpDependencyLogPrefix = "Decoding DumpDependency:"

func (dd *DumpDependency) UnmarshalJSON(b []byte) error {
	var raw map[string]any
	err := json.Unmarshal(b, &raw)
	if err != nil {
		return err
	}

	srcCtrlList, ok := jsonmap.Slice(raw, "sourceControl")
	if !ok {
		log.Println(dumpDependencyLogPrefix, "Expected to find `sourceControl`.")
		return nil
	}
	if len(srcCtrlList) == 0 {
		log.Println(dumpDependencyLogPrefix, "Expected at least one entry in `sourceControl` list.")
		return nil
	}
	srcCtrlEntry := srcCtrlList[0].(map[string]any)

	// Name
	dd.Name, ok = jsonmap.String(srcCtrlEntry, "identity")
	if !ok {
		log.Println(dumpDependencyLogPrefix, "Expected `identity` in source control entry.")
	}

	// URL
	location, ok := jsonmap.Map(srcCtrlEntry, "location")
	if ok {
		remotes, ok := jsonmap.Slice(location, "remote")
		if ok {
			if len(remotes) > 0 {
				dd.URL = remotes[0].(string)
			}
		}
	} else {
		log.Println(dumpDependencyLogPrefix, "Expected `location` in source control entry.")
	}

	return err
}
