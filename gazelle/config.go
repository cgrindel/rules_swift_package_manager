package gazelle

import (
	"flag"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
)

// Register Flags

func (*swiftLang) RegisterFlags(fs *flag.FlagSet, cmd string, c *config.Config) {
	// Initialize location for custom configuration
	sc := swiftcfg.NewSwiftConfig()

	// Store the config for later steps
	swiftcfg.SetSwiftConfig(c, sc)
}

func (sl *swiftLang) CheckFlags(fs *flag.FlagSet, c *config.Config) error {
	var err error
	sc := swiftcfg.GetSwiftConfig(c)
	mi := sc.ModuleIndex

	// GH021: Add flag so that the client can tell us which Swift to use.

	// Find the Swift executable
	if sc.SwiftBinPath, err = swiftbin.FindSwiftBinPath(); err != nil {
		return err
	}

	// TODO(chuck): I think that I should be loading the index from the file, not looking at the
	// individual repo rules.

	// All of the repository rules have been loaded into c.Repos. Process them.
	for _, r := range c.Repos {
		if err := mi.IndexRepoRule(r); err != nil {
			return err
		}
	}

	return nil
}
