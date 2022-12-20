package spdump

import (
	"encoding/json"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonutils"
)

type Dependency struct {
	SourceControl *SourceControl `json:"sourceControl"`
	FileSystem    *FileSystem    `json:"fileSystem"`
}

func (d *Dependency) Identity() string {
	if d.SourceControl != nil {
		return d.SourceControl.Identity
	}
	return ""
}

func (d *Dependency) URL() string {
	if d.SourceControl != nil {
		if d.SourceControl.Location.Remote != nil {
			return d.SourceControl.Location.Remote.URL
		}
	}
	return ""
}

// Source Control

type srcCtrl struct {
	Identity    string
	Location    *SourceControlLocation
	Requirement *DependencyRequirement
}

type SourceControl struct {
	Identity    string
	Location    *SourceControlLocation
	Requirement *DependencyRequirement
}

func (sc *SourceControl) UnmarshalJSON(b []byte) error {
	var raw []*srcCtrl
	err := json.Unmarshal(b, &raw)
	if err != nil {
		return err
	}
	rawSC := raw[0]
	sc.Identity = rawSC.Identity
	sc.Location = rawSC.Location
	sc.Requirement = rawSC.Requirement
	return nil
}

type SourceControlLocation struct {
	Remote *RemoteLocation
}

type RemoteLocation struct {
	URL string
}

func (rl *RemoteLocation) UnmarshalJSON(b []byte) error {
	var raw []any
	err := json.Unmarshal(b, &raw)
	if err != nil {
		return err
	}

	rl.URL, err = jsonutils.StringAtIndex(raw, 0)
	if err != nil {
		return err
	}
	return nil
}

type DependencyRequirement struct {
	Ranges []*VersionRange `json:"range"`
}

type VersionRange struct {
	LowerBound string
	UpperBound string
}

// FileSystem

type fSystem struct {
	Identity string
	Path     string
}

type FileSystem struct {
	Identity string
	Path     string
}

func (fs *FileSystem) UnmarshalJSON(b []byte) error {
	var raw []*fSystem
	err := json.Unmarshal(b, &raw)
	if err != nil {
		return err
	}
	rawFS := raw[0]
	fs.Identity = rawFS.Identity
	fs.Path = rawFS.Path
	return nil
}
