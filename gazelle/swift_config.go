package gazelle

import (
	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

// generateRulesMode

type generateRulesMode int

const (
	skipGenRulesMode generateRulesMode = iota
	swiftPkgGenRulesMode
	srcFileGenRulesMode
)

// Swift Config

const swiftConfigName = "swift"

type swiftConfig struct {
	swiftBinPath string
	// If this is true and a Package.swift is found, then use it to generate Bazel build files.
	genFromPkgManifest bool

	moduleFilesCollector ModuleFilesCollector
	moduleIndex          *swift.ModuleIndex
	packageInfo          *swiftpkg.PackageInfo
}

func newSwiftConfig() *swiftConfig {
	return &swiftConfig{
		moduleFilesCollector: NewModuleFilesCollector(),
		moduleIndex:          swift.NewModuleIndex(),
	}
}

func (sc *swiftConfig) swiftBin() *swiftbin.SwiftBin {
	return swiftbin.NewSwiftBin(sc.swiftBinPath)
}

// Determines how the specified directory should be processed.
func (sc *swiftConfig) generateRulesMode(args language.GenerateArgs) generateRulesMode {
	if sc.packageInfo == nil {
		return srcFileGenRulesMode
	} else if args.Dir == sc.packageInfo.Dir {
		return swiftPkgGenRulesMode
	}
	return skipGenRulesMode
}

func getSwiftConfig(c *config.Config) *swiftConfig {
	return c.Exts[swiftConfigName].(*swiftConfig)
}
