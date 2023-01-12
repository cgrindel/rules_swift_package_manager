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
		&sc.DependencyIndexRel,
		"swift_dependency_index",
		swiftcfg.DefaultDependencyIndexBasename,
		"the location of the dependency index JSON file",
	)

	switch cmd {
	case "update-repos":
		fs.BoolVar(
			&sc.UpdatePkgsToLatest,
			"swift_update_packages_to_latest",
			false,
			"Determines whether to update the Swift packages to their latest eligible version.")
	}

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
	if sc.DependencyIndexPath == "" {
		sc.DependencyIndexPath = filepath.Join(c.RepoRoot, sc.DependencyIndexRel)
	}

	// DEBUG BEGIN
	log.Printf("*** CHUCK:  sc.DependencyIndexRel: %+#v", sc.DependencyIndexRel)
	log.Printf("*** CHUCK:  sc.DependencyIndexPath: %+#v", sc.DependencyIndexPath)
	// DEBUG END

	// Attempt to load the module index. This is created by update-repos if the client is using
	// external Swift packages (e.g. swift_pacakge).
	if err = sc.LoadDependencyIndex(); err != nil {
		return err
	}
	// Index any of repository rules (e.g. http_archive) that may contain Swift targets.
	for _, r := range c.Repos {
		if err := sc.DependencyIndex.IndexRepoRule(r, c.RepoRoot); err != nil {
			return err
		}
	}

	return nil
}
