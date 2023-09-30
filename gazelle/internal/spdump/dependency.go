package spdump

import (
	"encoding/json"
	"errors"

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

type sourceControlLocationXcode15 struct {
	Remote []*RemoteLocation
}

type sourceControlLocationXcode14 struct {
	Remote *RemoteLocation
}

// A SourceControlLocation represents the location of a source control repository.
type SourceControlLocation struct {
	Remote *RemoteLocation
}

func (scl *SourceControlLocation) UnmarshalJSON(b []byte) error {

	// Try the Xcode 15 format first:
	var sclx15 sourceControlLocationXcode15
	err := json.Unmarshal(b, &sclx15)
	if err == nil {
		if len(sclx15.Remote) == 0 {
			return errors.New("source control location missing remote")
		}
		scl.Remote = sclx15.Remote[0]
		return nil
	}
	err = nil

	// Failing that, try the Xcode 14 format:
	var sclx14 sourceControlLocationXcode14
	err = json.Unmarshal(b, &sclx14)
	if err != nil {
		return err
	}
	scl.Remote = sclx14.Remote

	return nil
}

// A RemoteLocation represents a remote location for a source control repository.
type RemoteLocation struct {
	URL string
}

type remoteLocationXcode15 struct {
	URLString string `json:"urlString"`
}

func (rl *RemoteLocation) UnmarshalJSON(b []byte) error {

	// Try the Xcode 15 format first:
	var x15 remoteLocationXcode15
	err := json.Unmarshal(b, &x15)
	if err == nil {
		rl.URL = x15.URLString
		return nil
	}
	err = nil

	// Fall back to the Xcode 14 format if that failed:
	var raw []any
	err = json.Unmarshal(b, &raw)
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
