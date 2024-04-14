package swiftcfg

import (
	"log"
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
	MatchProtoGenerationMode         string = "match"
	PackageProtoGenerationMode       string = "package"
)

// A SwiftConfig represents the Swift-specific configuration for the Gazelle extension.
type SwiftConfig struct {
	SwiftBinPath              string
	ModuleFilesCollector      ModuleFilesCollector
	ShouldLoadDependencyIndex bool
	DependencyIndex           *swift.DependencyIndex
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

	// Whether or not the generated proto targets should omit the "Proto" suffix from their module names.
	OmitProtoSuffixFromModuleNames bool

	// The set of tags to apply to generated swift library targets.
	// Defaults to ["manual"]
	SwiftLibraryTags []string

	// The mode to use when generating swift_proto_library targets in a BUILD file with multiple proto_library targets.
	//
	// match: One swift_proto_library per proto_library target in the BUILD file. This is the default.
	// Its module name will be derived from the proto library name.
	//
	// package: If multiple proto_library targets share the same proto package,
	// they will be merged into a single swift_proto_library target.
	// Its module name will be derived from the proto package name.
	//
	SwiftProtoGenerationMode string

	// Whether or not to generate swift_proto_library targets for proto_library targets without services.
	// Defaults to true.
	GenerateSwiftProtoLibraries bool

	// The set of GRPC flavors for which swift_proto_library targets will be generated from proto libraries with services.
	// Defaults to:
	// [
	//  "swift_client_proto",
	//  "swift_server_proto"
	// ]
	GenerateSwiftProtoLibraryGRPCFlavors []string

	// The swift_proto_compiler targets to use for generated swift_proto_library targets.
	// The keys should match the GRPC flavors above, or "proto" for the base proto compiler.
	// Defaults to:
	// {
	// 	"swift_proto":       "@build_bazel_rules_swift//proto/compilers:swift_proto",
	// 	"swift_client_proto": "@build_bazel_rules_swift//proto/compilers:swift_client_proto",
	// 	"swift_server_proto": "@build_bazel_rules_swift//proto/compilers:swift_server_proto",
	// }
	SwiftProtoCompilers map[string]string

	// Mapping of relative path to default module name. These values are populated from directives
	// that can be applied to
	DefaultModuleNames map[string]string

	// Path to the YAML file that contains the patch information
	PatchesPath string

	// SwiftDepsInfoPath is the path for the Swift dependencies info JSON file.
	SwiftDepsInfoPath string
}

func NewSwiftConfig() *SwiftConfig {
	return &SwiftConfig{
		ModuleFilesCollector:           NewModuleFilesCollector(),
		DependencyIndex:                swift.NewDependencyIndex(),
		ResolutionLogger:               reslog.NewNoopLogger(),
		DefaultModuleNames:             make(map[string]string),
		ModuleNamingConvention:         "match_case",
		OmitProtoSuffixFromModuleNames: true,
		SwiftProtoGenerationMode:       "match",
		GenerateSwiftProtoLibraries:    true,
		GenerateSwiftProtoLibraryGRPCFlavors: []string{
			"swift_client_proto",
			"swift_server_proto",
		},
		SwiftProtoCompilers: map[string]string{
			"swift_proto":        "@build_bazel_rules_swift//proto/compilers:swift_proto",
			"swift_client_proto": "@build_bazel_rules_swift//proto/compilers:swift_client_proto",
			"swift_server_proto": "@build_bazel_rules_swift//proto/compilers:swift_server_proto",
		},
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

func (sc *SwiftConfig) LoadSwiftDepsInfo() (*swift.DepsInfo, error) {
	if sc.SwiftDepsInfoPath == "" {
		return nil, nil
	}
	data, err := os.ReadFile(sc.SwiftDepsInfoPath)
	if err != nil {
		return nil, err
	}
	return swift.NewDepsInfoFromJSON(data)
}

// LoadDependencyIndex reads the dependency index from disk.
func (sc *SwiftConfig) LoadDependencyIndex() error {
	swiftDepsInfo, err := sc.LoadSwiftDepsInfo()
	if err != nil {
		return err
	}
	if swiftDepsInfo == nil {
		return nil
	}

	// Read the pkg_info.json for each of the

	// DEBUG BEGIN
	log.Printf("*** CHUCK:  swiftDepsInfo: %+#v", swiftDepsInfo)
	// DEBUG END

	// TODO: IMPLEMENT ME!
	return nil
}

// func (sc *SwiftConfig) LoadDependencyIndex() error {
// 	if sc.DependencyIndexPath == "" {
// 		return nil
// 	}
// 	if _, err := os.Stat(sc.DependencyIndexPath); errors.Is(err, os.ErrNotExist) {
// 		return nil
// 	}
// 	data, err := os.ReadFile(sc.DependencyIndexPath)
// 	if err != nil {
// 		return err
// 	}
// 	sc.DependencyIndex, err = swift.NewDependencyIndexFromJSON(data)
// 	return err
// }

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
