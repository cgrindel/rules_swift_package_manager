package gazelle

import (
	"flag"
	"log"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
)

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

	// Initialize the module index path. We cannot initialize this path until we get into
	// CheckFlags.
	if sc.ModuleIndexPath == "" {
		sc.ModuleIndexPath = filepath.Join(c.RepoRoot, swiftcfg.DefaultModuleIndexBasename)
	}

	// Attempt to load the module index. This is created by update-repos if the client is using
	// external Swift packages (e.g. swift_pacakge).
	if err = sc.LoadModuleIndex(); err != nil {
		return err
	}
	// Index any of repository rules (e.g. http_archive) that may contain Swift targets.
	for _, r := range c.Repos {
		// DEBUG BEGIN
		log.Printf("*** CHUCK:  r.Name(): %+#v", r.Name())
		// DEBUG END
		if err := sc.ModuleIndex.IndexRepoRule(r); err != nil {
			return err
		}
	}

	return nil
}
