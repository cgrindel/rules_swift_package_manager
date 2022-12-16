package gazelle

import (
	"flag"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
)

const moduleIndexBasename = "module_index.json"

// Register Flags

func (*swiftLang) RegisterFlags(fs *flag.FlagSet, cmd string, c *config.Config) {
	// Initialize location for custom configuration
	sc := swiftcfg.NewSwiftConfig()

	fs.StringVar(
		&sc.ModuleIndexPath,
		"module_index",
		"",
		"the location of the module index JSON file",
	)

	// Store the config for later steps
	swiftcfg.SetSwiftConfig(c, sc)
}

func (sl *swiftLang) CheckFlags(fs *flag.FlagSet, c *config.Config) error {
	var err error
	sc := swiftcfg.GetSwiftConfig(c)

	// GH021: Add flag so that the client can tell us which Swift to use.

	// Find the Swift executable
	if sc.SwiftBinPath, err = swiftbin.FindSwiftBinPath(); err != nil {
		return err
	}

	// We cannot initialize this path until we get into CheckFlags
	if sc.ModuleIndexPath == "" {
		sc.ModuleIndexPath = filepath.Join(c.RepoRoot, moduleIndexBasename)
	}

	// Load the module index
	if err = sc.LoadModuleIndex(); err != nil {
		return err
	}

	return nil
}
