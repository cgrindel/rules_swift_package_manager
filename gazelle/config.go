package gazelle

import (
	"flag"
	"fmt"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
	"github.com/cgrindel/swift_bazel/gazelle/internal/wspace"
)

// Register Flags

func (*swiftLang) RegisterFlags(fs *flag.FlagSet, cmd string, c *config.Config) {
	// Initialize location for custom configuration
	sc := swiftcfg.NewSwiftConfig()

	switch cmd {
	case "fix", "update":
		fs.BoolVar(
			&sc.GenFromPkgManifest,
			"gen_from_pkg_manifest",
			false,
			"If set and a Package.swift file is found, then generate build files from manifest info.",
		)

		// case "update-repos":
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
	sb := sc.SwiftBin()

	shouldProcWkspFile := true
	if sc.GenFromPkgManifest {
		if pi, err := swiftpkg.NewPackageInfo(sb, c.RepoRoot); err != nil {
			return err
		} else if pi != nil {
			shouldProcWkspFile = false
			sc.PackageInfo = pi
		}
	}

	if shouldProcWkspFile {
		// Look for http_archive declarations with Swift declarations.
		if err = findExternalDepsInWorkspace(sc.ModuleIndex, c.RepoRoot); err != nil {
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
