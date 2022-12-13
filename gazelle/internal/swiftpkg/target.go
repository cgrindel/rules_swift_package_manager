package swiftpkg

import (
	"fmt"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdesc"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
)

// TargetType

type TargetType int

const (
	UnknownTargetType TargetType = iota
	ExecutableTargetType
	LibraryTargetType
	TestTargetType
)

// Targets

type Targets []*Target

func (ts Targets) FindByName(name string) *Target {
	for _, t := range ts {
		if t.Name == name {
			return t
		}
	}
	return nil
}

func (ts Targets) FindByPath(path string) *Target {
	for _, t := range ts {
		if t.Path == path {
			return t
		}
	}
	return nil
}

// Target

type Target struct {
	Name         string
	C99name      string
	Type         TargetType
	ModuleType   string
	Path         string
	Sources      []string
	Dependencies []*TargetDependency
}

func NewTargetFromManifestInfo(descT *spdesc.Target, dumpT *spdump.Target) (*Target, error) {
	var targetType TargetType
	switch dumpT.Type {
	case spdump.UnknownTargetType:
		targetType = UnknownTargetType
	case spdump.ExecutableTargetType:
		targetType = ExecutableTargetType
	case spdump.LibraryTargetType:
		targetType = LibraryTargetType
	case spdump.TestTargetType:
		targetType = TestTargetType
	default:
		return nil, fmt.Errorf(
			"unrecognized spdump.TargetType %v for %s target", dumpT.Type, dumpT.Name)
	}

	var err error
	tdeps := make([]*TargetDependency, len(dumpT.Dependencies))
	for idx, td := range dumpT.Dependencies {
		tdeps[idx], err = NewTargetDependencyFromManifestInfo(&td)
		if err != nil {
			return nil, fmt.Errorf("failed creating target dep for %s: %w", dumpT.Name, err)
		}
	}

	return &Target{
		Name:         descT.Name,
		C99name:      descT.C99name,
		Type:         targetType,
		ModuleType:   descT.ModuleType,
		Path:         descT.Path,
		Sources:      descT.Sources,
		Dependencies: tdeps,
	}, nil
}
