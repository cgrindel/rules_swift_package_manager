package swiftpkg

import (
	"log"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
)

type Dependency struct {
	SourceControl *SourceControl
}

func (d *Dependency) Identity() string {
	if d.SourceControl != nil {
		return d.SourceControl.Identity
	}
	log.Fatalf("Identity could not be determined.")
	return ""
}

func NewDependencyFromManifestInfo(dumpD *spdump.Dependency) (*Dependency, error) {
	// TODO(chuck): IMPLEMENT ME!
	return nil, nil
}

type SourceControl struct {
	Identity    string
	URL         string
	Requirement DependencyRequirement
}

// Requirement

type DependencyRequirement struct {
	Range []VersionRange
}

type VersionRange struct {
	LowerBound string
	UpperBound string
}
