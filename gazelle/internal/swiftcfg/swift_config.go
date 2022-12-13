package swiftcfg

import (
	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

const SwiftConfigName = "swift"

type SwiftConfig struct {
	SwiftBinPath string
	// If this is true and a Package.swift is found, then use it to generate Bazel build files.
	GenFromPkgManifest bool

	ModuleFilesCollector ModuleFilesCollector
	ModuleIndex          *swift.ModuleIndex
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
