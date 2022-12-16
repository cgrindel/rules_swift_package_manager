package swiftcfg

import (
	"os"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

const SwiftConfigName = "swift"
const DefaultModuleIndexBasename = "module_index.json"
const moduleIndexPerms = 0666

type SwiftConfig struct {
	SwiftBinPath         string
	ModuleFilesCollector ModuleFilesCollector
	ModuleIndex          *swift.ModuleIndex
	ModuleIndexPath      string
	PackageInfo          *swiftpkg.PackageInfo
}

func NewSwiftConfig() *SwiftConfig {
	return &SwiftConfig{
		ModuleFilesCollector: NewModuleFilesCollector(),
		ModuleIndex:          swift.NewModuleIndex(),
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

func (sc *SwiftConfig) LoadModuleIndex() error {
	data, err := os.ReadFile(sc.ModuleIndexPath)
	if err != nil {
		return err
	}
	sc.ModuleIndex, err = swift.NewModuleIndexFromJSON(data)
	return err
}

func (sc *SwiftConfig) WriteModuleIndex() error {
	data, err := sc.ModuleIndex.JSON()
	if err != nil {
		return err
	}
	return os.WriteFile(sc.ModuleIndexPath, data, moduleIndexPerms)
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
