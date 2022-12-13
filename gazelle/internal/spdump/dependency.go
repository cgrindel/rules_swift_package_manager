package spdump

import (
	"encoding/json"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonutils"
)

type Dependency struct {
	SourceControl *SourceControl `json:"sourceControl"`
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
