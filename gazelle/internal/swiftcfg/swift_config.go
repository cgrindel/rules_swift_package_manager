package swiftcfg

import (
	"errors"
	"os"
	"sort"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/reslog"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swiftbin"
)

const SwiftConfigName = "swift"
const DefaultDependencyIndexBasename = "swift_deps_index.json"
const dependencyIndexPerms = 0666

const (
	MatchCaseModuleNamingConvention  string = "match_case"
	PascalCaseModuleNamingConvention string = "pascal_case"
)

// A SwiftConfig represents the Swift-specific configuration for the Gazelle extension.
type SwiftConfig struct {
	SwiftBinPath         string
	ModuleFilesCollector ModuleFilesCollector
	DependencyIndex      *swift.DependencyIndex
	// DependencyIndexRel is the path relative to the RepoRoot to the dependency index
	DependencyIndexRel string
	// DependencyIndexPath is the full path to the dependency index
	DependencyIndexPath      string
	UpdatePkgsToLatest       bool
	ResolutionLogPath        string
	ResolutionLogFile        *os.File
	ResolutionLogger         reslog.ResolutionLogger
	UpdateBzlmodUseRepoNames bool
	PrintBzlmodStanzas       bool
	UpdateBzlmodStanzas      bool
	BazelModuleRel           string
	// BazelModulePath is the full path to the MODULE.bazel
	BazelModulePath string

	GenerateSwiftDepsForWorkspace bool

	// The naming convention to apply to the module names derived from the directory names.
	// The default behavior uses the name verbatim while PascalCase will convert snake_case to PascalCase.
	ModuleNamingConvention string

	// The set of tags to apply to generated swift library targets.
	// Defaults to ["manual"]
	SwiftLibraryTags []string

	// Whether or not to generate swift proto library targets.
	GenerateProtoLibraries bool

	// The set of GRPC flavors for which swift grpc library targets will be generated.
	// Defaults to ["client,client_stubs,server"]
	GenerateGRPCLibraryFlavors []string

	// Mapping of relative path to default module name. These values are populated from directives
	// that can be applied to
	DefaultModuleNames map[string]string

	// Path to the YAML file that contains the patch information
	PatchesPath string
}

func NewSwiftConfig() *SwiftConfig {
	return &SwiftConfig{
		ModuleFilesCollector: NewModuleFilesCollector(),
		DependencyIndex:      swift.NewDependencyIndex(),
		ResolutionLogger:     reslog.NewNoopLogger(),
		DefaultModuleNames:   make(map[string]string),
	}
}

func (sc *SwiftConfig) ConfigModulePaths() []string {
	dmnLen := len(sc.DefaultModuleNames)
	if dmnLen == 0 {
		return nil
	}
	modPaths := make([]string, 0, dmnLen)
	for modPath := range sc.DefaultModuleNames {
		modPaths = append(modPaths, modPath)
	}
	// Ensure that the results are consistent
	sort.Strings(modPaths)
	return modPaths
}

// SwiftBin returns the Swift binary.
func (sc *SwiftConfig) SwiftBin() *swiftbin.SwiftBin {
	if sc.SwiftBinPath == "" {
		return nil
	}
	return swiftbin.NewSwiftBin(sc.SwiftBinPath)
}

// GenerateRulesMode determines how the specified directory should be processed.
func (sc *SwiftConfig) GenerateRulesMode(args language.GenerateArgs) GenerateRulesMode {
	// We only support source file generation in the Gazelle extension.
	return SrcFileGenRulesMode
}

// LoadDependencyIndex reads the dependency index from disk.
func (sc *SwiftConfig) LoadDependencyIndex() error {
	if sc.DependencyIndexPath == "" {
		return nil
	}
	if _, err := os.Stat(sc.DependencyIndexPath); errors.Is(err, os.ErrNotExist) {
		return nil
	}
	data, err := os.ReadFile(sc.DependencyIndexPath)
	if err != nil {
		return err
	}
	sc.DependencyIndex, err = swift.NewDependencyIndexFromJSON(data)
	return err
}

// WriteDependencyIndex writes the dependency index to disk.
func (sc *SwiftConfig) WriteDependencyIndex() error {
	data, err := sc.DependencyIndex.JSON()
	if err != nil {
		return err
	}
	return os.WriteFile(sc.DependencyIndexPath, data, dependencyIndexPerms)
}

// GetSwiftConfig extracts the Swift configuration from the Gazelle configuration.
func GetSwiftConfig(c *config.Config) *SwiftConfig {
	scAny := c.Exts[SwiftConfigName]
	if scAny == nil {
		return nil
	}
	return scAny.(*SwiftConfig)
}

// SetSwiftConfig stores the Swift configuration in the Gazelle configuration.
func SetSwiftConfig(c *config.Config, sc *SwiftConfig) {
	c.Exts[SwiftConfigName] = sc
}
