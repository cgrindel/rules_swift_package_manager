package spdump

import (
	"encoding/json"
	"log"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonutils"
	"github.com/hashicorp/go-multierror"
)

type Dependency struct {
	Name        string
	URL         string
	Requirement DependencyRequirement
}

type DependencyRequirement struct {
	Range []VersionRange
}

type VersionRange struct {
	LowerBound string
	UpperBound string
}

const dependencyLogPrefix = "Decoding Dependency:"

func (d *Dependency) UnmarshalJSON(b []byte) error {
	var errs error

	var raw map[string]any
	err := json.Unmarshal(b, &raw)
	if err != nil {
		return err
	}

	srcCtrlList, err := jsonutils.SliceAtKey(raw, "sourceControl")
	if err != nil {
		return err
	}
	if len(srcCtrlList) == 0 {
		log.Println(dependencyLogPrefix, "Expected at least one entry in `sourceControl` list.")
		return nil
	}
	srcCtrlEntry := srcCtrlList[0].(map[string]any)

	// Name
	if d.Name, err = jsonutils.StringAtKey(srcCtrlEntry, "identity"); err != nil {
		errs = multierror.Append(errs, err)
	}

	// URL
	if location, err := jsonutils.MapAtKey(srcCtrlEntry, "location"); err == nil {
		if remotes, err := jsonutils.SliceAtKey(location, "remote"); err == nil {
			if len(remotes) > 0 {
				d.URL = remotes[0].(string)
			}
		} else {
			errs = multierror.Append(errs, err)
		}
	} else {
		errs = multierror.Append(errs, err)
	}

	// Requirement
	if err = jsonutils.UnmarshalAtKey(srcCtrlEntry, "requirement", &d.Requirement); err != nil {
		errs = multierror.Append(errs, err)
	}

	return errs
}
