package swift

import (
	"fmt"
	"path/filepath"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
)

type Package struct {
	Name     string         `json:"name"`
	Identity string         `json:"identity"`
	Local    *LocalPackage  `json:"local,omitempty"`
	Remote   *RemotePackage `json:"remote,omitempty"`
}

type LocalPackage struct {
	Path string `json:"path"`
}

type RemotePackage struct {
	Commit  string `json:"commit"`
	Remote  string `json:"remote"`
	Version string `json:"version,omitempty"`
	Branch  string `json:"branch,omitempty"`
}

func NewPackageFromBazelRepo(bzlRepo *BazelRepo, diRel string, pkgDir string) (*Package, error) {
	var err error
	p := Package{Name: bzlRepo.Name, Identity: bzlRepo.Identity}
	if bzlRepo.Pin != nil {
		p.Remote, err = remotePackageFromPin(bzlRepo.Name, bzlRepo.Pin)
		if err != nil {
			return nil, err
		}
	} else {
		relPath, err := filepath.Rel(pkgDir, bzlRepo.PkgInfo.Path)
		if err != nil {
			return nil, err
		}
		p.Local = &LocalPackage{Path: relPath}
	}
	return &p, nil
}

// The modules parameter is a map of the module name (key) to the relative Bazel label (value).
func remotePackageFromPin(repoName string, p *spreso.Pin) (*RemotePackage, error) {
	cp, ok := p.State.(commitProvider)
	if !ok {
		return nil, fmt.Errorf("expected pin state to provide a commit hash %T", p.State)
	}
	rp := RemotePackage{
		Commit: cp.Commit(),
		Remote: p.PkgRef.Remote(),
	}
	switch t := p.State.(type) {
	case *spreso.VersionPinState:
		rp.Version = t.Version
	case *spreso.BranchPinState:
		rp.Branch = t.Name
	}
	return &rp, nil
}
