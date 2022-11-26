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
	if sc.PackageInfo == nil {
		return SrcFileGenRulesMode
	} else if args.Dir == sc.PackageInfo.Dir {
		return SwiftPkgGenRulesMode
	}
	return SkipGenRulesMode
}

func GetSwiftConfig(c *config.Config) *SwiftConfig {
	return c.Exts[SwiftConfigName].(*SwiftConfig)
}

func SetSwiftConfig(c *config.Config, sc *SwiftConfig) {
	c.Exts[SwiftConfigName] = sc
}


