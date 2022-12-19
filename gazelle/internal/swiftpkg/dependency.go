package swiftpkg

import (
	"log"
	"path"
	"path/filepath"
	"strings"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
)

const swiftPkgBuildDirname = ".build"
const swiftPkgCheckoutsDirname = "checkouts"

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

// TODO(chuck): What do we want to do with URL() and FileSystem?

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

// Returns the path to the dependency's code. For source control dependencies, it is the checkout
// directory. For local packages, it is the path to the local package.
func (d *Dependency) CodeDir(pkgDir string) string {
	if d.SourceControl != nil {
		// Return the checkout directory
		return filepath.Join(
			pkgDir,
			swiftPkgBuildDirname,
			swiftPkgCheckoutsDirname,
			d.spmCheckoutDirname(),
		)
	}
	if d.FileSystem != nil {
		// Return the local path
		return filepath.Clean(filepath.Join(pkgDir, d.FileSystem.Path))
	}
	log.Fatalf("CodeDir could not be determined.")
	return ""
}

func (d *Dependency) spmCheckoutDirname() string {
	url := d.URL()
	base := path.Base(url)
	ext := path.Ext(base)
	if ext == "" {
		return base
	}
	return strings.TrimSuffix(base, ext)
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
