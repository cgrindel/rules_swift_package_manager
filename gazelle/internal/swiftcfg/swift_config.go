package swiftcfg

import (
	"errors"
	"os"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

const SwiftConfigName = "swift"
const DefaultDependencyIndexBasename = "swift_deps_index.json"
const dependencyIndexPerms = 0666

type SwiftConfig struct {
	SwiftBinPath         string
	ModuleFilesCollector ModuleFilesCollector
	DependencyIndex      *swift.DependencyIndex
	// DependencyIndexRel is the path relative to the RepoRoot to the dependency index
	DependencyIndexRel string
	// DependencyIndexPath is the full path to the dependency index
	DependencyIndexPath string
	PackageInfo         *swiftpkg.PackageInfo
	UpdatePkgsToLatest  bool
}

func NewSwiftConfig() *SwiftConfig {
	return &SwiftConfig{
		ModuleFilesCollector: NewModuleFilesCollector(),
		DependencyIndex:      swift.NewDependencyIndex(),
	}
}

func (sc *SwiftConfig) SwiftBin() *swiftbin.SwiftBin {
	if sc.SwiftBinPath == "" {
		return nil
	}
	return swiftbin.NewSwiftBin(sc.SwiftBinPath)
}

// Determines how the specified directory should be processed.
func (sc *SwiftConfig) GenerateRulesMode(args language.GenerateArgs) GenerateRulesMode {
	pi := sc.PackageInfo
	if pi == nil {
		return SrcFileGenRulesMode
	} else if args.Dir == pi.Path {
		return SwiftPkgGenRulesMode
	} else if desct := pi.Targets.FindByPath(args.Rel); desct != nil {
		return SwiftPkgGenRulesMode
	}
	return SkipGenRulesMode
}

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

func (sc *SwiftConfig) WriteDependencyIndex() error {
	data, err := sc.DependencyIndex.JSON()
	if err != nil {
		return err
	}
	return os.WriteFile(sc.DependencyIndexPath, data, dependencyIndexPerms)
}

func GetSwiftConfig(c *config.Config) *SwiftConfig {
	scAny := c.Exts[SwiftConfigName]
	if scAny == nil {
		return nil
	}
	return scAny.(*SwiftConfig)
}

func SetSwiftConfig(c *config.Config, sc *SwiftConfig) {
	c.Exts[SwiftConfigName] = sc
}
