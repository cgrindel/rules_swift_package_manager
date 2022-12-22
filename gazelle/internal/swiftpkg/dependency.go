package swiftpkg

import (
	"log"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
)

type Dependency struct {
	SourceControl *SourceControl
	FileSystem    *FileSystem
}

func NewDependencyFromManifestInfo(dumpD *spdump.Dependency) (*Dependency, error) {
	var srcCtrl *SourceControl
	if dumpD.SourceControl != nil {
		srcCtrl = NewSourceControlFromManifestInfo(dumpD.SourceControl)
	}
	var fSys *FileSystem
	if dumpD.FileSystem != nil {
		fSys = NewFileSystemFromManifestInfo(dumpD.FileSystem)
	}
	return &Dependency{
		SourceControl: srcCtrl,
		FileSystem:    fSys,
	}, nil
}

func (d *Dependency) Identity() string {
	if d.SourceControl != nil {
		return d.SourceControl.Identity
	}
	if d.FileSystem != nil {
		return d.FileSystem.Identity
	}
	log.Fatalf("Identity could not be determined.")
	return ""
}

func (d *Dependency) URL() string {
	if d.SourceControl != nil {
		if d.SourceControl.Location != nil {
			if d.SourceControl.Location.Remote != nil {
				return d.SourceControl.Location.Remote.URL
			}
		}
	}
	log.Fatalf("URL could not be determined.")
	return ""
}

// SourceControl

type SourceControl struct {
	Identity    string
	Location    *SourceControlLocation
	Requirement *DependencyRequirement
}

func NewSourceControlFromManifestInfo(dumpSC *spdump.SourceControl) *SourceControl {
	return &SourceControl{
		Identity:    dumpSC.Identity,
		Location:    NewSourceControlLocationFromManifestInfo(dumpSC.Location),
		Requirement: NewDependencyRequirementFromManifestInfo(dumpSC.Requirement),
	}
}

type SourceControlLocation struct {
	Remote *RemoteLocation
}

func NewSourceControlLocationFromManifestInfo(dumpL *spdump.SourceControlLocation) *SourceControlLocation {
	return &SourceControlLocation{
		Remote: NewRemoteLocationFromManifestInfo(dumpL.Remote),
	}
}

type RemoteLocation struct {
	URL string
}

func NewRemoteLocationFromManifestInfo(rl *spdump.RemoteLocation) *RemoteLocation {
	return &RemoteLocation{
		URL: rl.URL,
	}
}

// DependencyRequirement

type DependencyRequirement struct {
	Ranges []*VersionRange
}

func NewDependencyRequirementFromManifestInfo(dr *spdump.DependencyRequirement) *DependencyRequirement {
	ranges := make([]*VersionRange, len(dr.Ranges))
	for idx, r := range dr.Ranges {
		ranges[idx] = NewVersionRangeFromManifestInfo(r)
	}

	return &DependencyRequirement{
		Ranges: ranges,
	}
}

// VersionRange

type VersionRange struct {
	LowerBound string
	UpperBound string
}

func NewVersionRangeFromManifestInfo(vr *spdump.VersionRange) *VersionRange {
	return &VersionRange{
		LowerBound: vr.LowerBound,
		UpperBound: vr.UpperBound,
	}
}

// FileSystem

type FileSystem struct {
	Identity string
	Path     string
}

func NewFileSystemFromManifestInfo(fs *spdump.FileSystem) *FileSystem {
	return &FileSystem{
		Identity: fs.Identity,
		Path:     fs.Path,
	}
}
