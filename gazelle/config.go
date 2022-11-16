package gazelle

import (
	"flag"
	"fmt"
	"log"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/wspace"
)

const swiftConfigName = "swift"

type swiftConfig struct {
	moduleIndex *swift.ModuleIndex
}

func getSwiftConfig(c *config.Config) *swiftConfig {
	return c.Exts[swiftConfigName].(*swiftConfig)
}

func (*swiftLang) RegisterFlags(fs *flag.FlagSet, cmd string, c *config.Config) {
	// DEBUG BEGIN
	log.Printf("*** CHUCK: RegisterFlags ========")
	log.Printf("*** CHUCK: RegisterFlags c: %+#v", c)
	// DEBUG END
	// Initialize location for custom configuration
	sc := &swiftConfig{
		moduleIndex: swift.NewModuleIndex(),
	}
	c.Exts[swiftConfigName] = sc
}

func (sl *swiftLang) CheckFlags(fs *flag.FlagSet, c *config.Config) error {
	sc := getSwiftConfig(c)

	// DEBUG BEGIN
	log.Printf("*** CHUCK: CheckFlags ========")
	log.Printf("*** CHUCK: CheckFlags c: %+#v", c)
	log.Printf("*** CHUCK: CheckFlags sc: %+#v", sc)
	// DEBUG END

	wkspFilePath := wspace.FindWORKSPACEFile(c.RepoRoot)
	wkspFile, err := rule.LoadWorkspaceFile(wkspFilePath, "")
	if err != nil {
		return fmt.Errorf("failed to load WORKSPACE file %v: %w", wkspFilePath, err)
	}
	archives, err := swift.NewHTTPArchivesFromWkspFile(wkspFile)
	if err != nil {
		return fmt.Errorf(
			"failed to retrieve archives from workspace file %v: %w",
			wkspFilePath,
			err,
		)
	}
	for _, archive := range archives {
		sc.moduleIndex.AddModules(archive.Modules...)
	}

	return nil
}
