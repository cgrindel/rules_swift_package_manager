package gazelle

import (
	"flag"
	"fmt"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
	"github.com/cgrindel/swift_bazel/gazelle/internal/wspace"
)

const swiftConfigName = "swift"

type swiftConfig struct {
	moduleIndex  *swift.ModuleIndex
	swiftBinPath string
	// If this is true and a Package.swift is found, then use it to generate Bazel build files.
	genFromPkgManifest bool
}

func (sc *swiftConfig) swiftBin() *swiftbin.SwiftBin {
	return swiftbin.NewSwiftBin(sc.swiftBinPath)
}

func getSwiftConfig(c *config.Config) *swiftConfig {
	return c.Exts[swiftConfigName].(*swiftConfig)
}

func (*swiftLang) RegisterFlags(fs *flag.FlagSet, cmd string, c *config.Config) {
	// Initialize location for custom configuration
	sc := &swiftConfig{
		moduleIndex: swift.NewModuleIndex(),
	}

	switch cmd {
	case "fix", "update":
		fs.BoolVar(
			&sc.genFromPkgManifest,
			"gen_from_pkg_manifest",
			false,
			"If set and a Package.swift file is found, then generate build files from manifest info.",
		)

		// case "update-repos":
	}

	// Store the config for later steps
	c.Exts[swiftConfigName] = sc
}

func (sl *swiftLang) CheckFlags(fs *flag.FlagSet, c *config.Config) error {
	var err error
	sc := getSwiftConfig(c)

	// TODO(chuck): Add flag so that the client can tell us which Swift to use.

	// Find the Swift executable
	if sc.swiftBinPath, err = swiftbin.FindSwiftBinPath(); err != nil {
		return err
	}

	shouldProcWkspFile := true
	if sc.genFromPkgManifest {
		if pkg, err := swiftpkg.FindPackageInfo(c.RepoRoot); err != nil {
			return err
		} else if pkg != nil {
			shouldProcWkspFile = false
			if err = processSwiftPackage(sc, pkg); err != nil {
				return err
			}
		}
	}

	if shouldProcWkspFile {
		// Look for http_archive declarations with Swift declarations.
		if err = findExternalDepsInWorkspace(sc.moduleIndex, c.RepoRoot); err != nil {
			return err
		}
	}

	return nil
}

func findExternalDepsInWorkspace(mi *swift.ModuleIndex, repoRoot string) error {
	wkspFilePath := wspace.FindWORKSPACEFile(repoRoot)
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
		mi.AddModules(archive.Modules...)
	}
	return nil
}

func processSwiftPackage(sc *swiftConfig, pkg *swiftpkg.PackageInfo) error {
	sb := sc.swiftBin()
	// We may not want to resolve here. We may want to resolve during update-repos.
	if err := pkg.Read(sb); err != nil {
		return err
	}

	// TODO(chuck): Generate a BUILD file with everything from the module OR store the info in the
	// config and generate build files as we visit the appropriate directories.

	return nil
}
