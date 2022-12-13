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
	Range []*VersionRange
}

type VersionRange struct {
	LowerBound string
	UpperBound string
}

// const dependencyLogPrefix = "Decoding Dependency:"

// func (d *Dependency) UnmarshalJSON(b []byte) error {
// 	var errs error

// 	var raw map[string]any
// 	err := json.Unmarshal(b, &raw)
// 	if err != nil {
// 		return err
// 	}

// 	srcCtrlList, err := jsonutils.SliceAtKey(raw, "sourceControl")
// 	if err != nil {
// 		return err
// 	}
// 	if len(srcCtrlList) == 0 {
// 		log.Println(dependencyLogPrefix, "Expected at least one entry in `sourceControl` list.")
// 		return nil
// 	}
// 	srcCtrlEntry := srcCtrlList[0].(map[string]any)

// 	// Name
// 	if d.Name, err = jsonutils.StringAtKey(srcCtrlEntry, "identity"); err != nil {
// 		errs = multierror.Append(errs, err)
// 	}

// 	// URL
// 	if location, err := jsonutils.MapAtKey(srcCtrlEntry, "location"); err == nil {
// 		if remotes, err := jsonutils.SliceAtKey(location, "remote"); err == nil {
// 			if len(remotes) > 0 {
// 				d.URL = remotes[0].(string)
// 			}
// 		} else {
// 			errs = multierror.Append(errs, err)
// 		}
// 	} else {
// 		errs = multierror.Append(errs, err)
// 	}

// 	// Requirement
// 	if err = jsonutils.UnmarshalAtKey(srcCtrlEntry, "requirement", &d.Requirement); err != nil {
// 		errs = multierror.Append(errs, err)
// 	}

// 	return errs
// }
