package spdump

import (
	"encoding/json"

	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/jsonutils"
)

// A Dependency represents an external dependency.
type Dependency struct {
	SourceControl *SourceControl `json:"sourceControl"`
	FileSystem    *FileSystem    `json:"fileSystem"`
}

// Identity returns the value that identifies the external dependency in the manifest.
func (d *Dependency) Identity() string {
	if d.SourceControl != nil {
		return d.SourceControl.Identity
	}
	return ""
}

// URL returns the URL for the external dependency.
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

// A SourceControl represents the retrieval information for an external dependency in a source
// control server.
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

// A SourceControlLocation represents the location of a source control repository.
type SourceControlLocation struct {
	Remote *RemoteLocation
}

// A RemoteLocation represents a remote location for a source control repository.
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

// A DependencyRequirement represents the eligibility requirements for an external dependency.
type DependencyRequirement struct {
	Ranges []*VersionRange `json:"range"`
}

// A VersionRange represents a semver range for an external dependency.
type VersionRange struct {
	LowerBound string
	UpperBound string
}

// FileSystem

type fSystem struct {
	Identity string
	Path     string
}

// FileSystem represents the location of an external dependency as a local Swift package.
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
