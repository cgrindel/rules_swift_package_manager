package swiftpkg

import (
	"encoding/json"
	"fmt"
	"path/filepath"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spdesc"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spdump"
	mapset "github.com/deckarep/golang-set/v2"
)

// TargetType

// A TargetType is an enum for a Swift target type.
type TargetType int

const (
	UnknownTargetType TargetType = iota
	ExecutableTargetType
	LibraryTargetType
	TestTargetType
	PluginTargetType
)

func (tt *TargetType) UnmarshalJSON(b []byte) error {
	var ttStr string
	err := json.Unmarshal(b, &ttStr)
	if err != nil {
		return err
	}
	switch ttStr {
	case "executable":
		*tt = ExecutableTargetType
	case "test":
		*tt = TestTargetType
	case "library", "regular":
		*tt = LibraryTargetType
	case "plugin":
		*tt = PluginTargetType
	default:
		*tt = UnknownTargetType
	}
	return nil
}

// Targets

// A Targets represents a slice of Swift targets.
type Targets []*Target

// FindByName returns the target with the matching name. Otherwise, returns nil.
func (ts Targets) FindByName(name string) *Target {
	for _, t := range ts {
		if t.Name == name {
			return t
		}
	}
	return nil
}

// FindByPath returns the target with the matching path. Otherwise, returns nil.
func (ts Targets) FindByPath(path string) *Target {
	for _, t := range ts {
		if t.Path == path {
			return t
		}
	}
	return nil
}

// Target

// A Target represents a Swift target.
type Target struct {
	Name               string
	C99name            string
	Type               TargetType
	ModuleType         ModuleType
	Path               string
	Sources            []string
	Dependencies       []*TargetDependency
	CSettings          *ClangSettings
	SrcType            SourceType
	ProductMemberships []string `json:"product_memberships"`
	// SwiftFileInfos will only be populated if the target is a Swift target.
	SwiftFileInfos SwiftFileInfos
}

// NewTargetFromManifestInfo returns a Swift target from manifest information.
func NewTargetFromManifestInfo(
	pkgPath string,
	descT *spdesc.Target,
	dumpT *spdump.Target,
	prodNames mapset.Set[string],
) (*Target, error) {
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
	case spdump.PluginTargetType:
		targetType = PluginTargetType
	default:
		return nil, fmt.Errorf(
			"unrecognized spdump.TargetType %v for %s target", dumpT.Type, dumpT.Name)
	}
	moduleType := NewModuleType(descT.ModuleType)
	srcType := NewSourceType(moduleType, descT.Sources)

	var swiftFileInfos SwiftFileInfos
	if srcType == SwiftSourceType {
		targetPath := filepath.Join(pkgPath, descT.Path)
		swiftFileInfos = NewSwiftFileInfosFromRelPaths(targetPath, descT.Sources)
	}

	// GH046: A Swift plugin can have a dependency on an executable target. In this case, we
	// want to add the target as a data dependency.

	var err error
	tdeps := make([]*TargetDependency, len(dumpT.Dependencies))
	for idx, td := range dumpT.Dependencies {
		tdeps[idx], err = NewTargetDependencyFromManifestInfo(&td)
		if err != nil {
			return nil, fmt.Errorf("failed creating target dep for %s: %w", dumpT.Name, err)
		}
	}

	cSettings, err := NewClangSettingsFromManifestInfo(dumpT.Settings)
	if err != nil {
		return nil, err
	}

	// The description JSON can contain phantom products. These are products that are not declared
	// in the original package manifest (e.g., executable target not associated with a product). We
	// do not want to include these phantoms as SPM package resolution may not include all of the
	// external dependencies for these products. (SPM only resolves non-test external dependencies.)
	prodMemberships := make([]string, 0, len(descT.ProductMemberships))
	for _, prodName := range descT.ProductMemberships {
		if prodNames.Contains(prodName) {
			prodMemberships = append(prodMemberships, prodName)
		}
	}

	return &Target{
		Name:               descT.Name,
		C99name:            descT.C99name,
		Type:               targetType,
		ModuleType:         moduleType,
		Path:               descT.Path,
		Sources:            descT.Sources,
		Dependencies:       tdeps,
		CSettings:          cSettings,
		SrcType:            srcType,
		ProductMemberships: prodMemberships,
		SwiftFileInfos:     swiftFileInfos,
	}, nil
}

// Imports returns the module names provided by the dependencies.
func (t *Target) Imports() []string {
	imports := make([]string, len(t.Dependencies))
	for idx, td := range t.Dependencies {
		imports[idx] = td.ImportName()
	}
	return imports
}

// ClangSettings

// A ClangSettings represents the clang-specific settings for a Swift target.
type ClangSettings struct {
	Defines []string
}

// NewClangSettingsFromManifestInfo returns the clang settings from manfiest information.
func NewClangSettingsFromManifestInfo(dumpTS []spdump.TargetSetting) (*ClangSettings, error) {
	cSettings := &ClangSettings{}
	for _, ts := range dumpTS {
		if ts.Tool != spdump.ClangToolType {
			continue
		}
		if ts.Kind == spdump.DefineTargetSettingKind {
			cSettings.Defines = append(cSettings.Defines, ts.Defines...)
		}
	}
	return cSettings, nil
}
