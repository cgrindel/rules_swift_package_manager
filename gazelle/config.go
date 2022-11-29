package gazelle

import (
	"flag"
	"fmt"
	"log"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/label"
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
			findExternalDepsInManifest(sc.ModuleIndex, pi)
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

func findExternalDepsInManifest(mi *swift.ModuleIndex, pi *swiftpkg.PackageInfo) {
	var err error
	dump := pi.DumpManifest

	// Create a map of Swift external dep identity and Bazel repo name
	depIdentToBazelRepoName := make(map[string]string)
	for _, d := range dump.Dependencies {
		depIdentToBazelRepoName[d.Name], err = swift.RepoName(d.URL)
		if err != nil {
			log.Fatalf("Failed to create repo name for %s: %w", d.Name, err)
		}
	}

	// Find all of the unique product references (under TargetDependency)
	prodRefs := dump.ProductReferences()

	// Create a Module for each product reference
	for _, pr := range prodRefs {
		// For external deps, the product name appears toe always be the Swift module name
		repo, ok := depIdentToBazelRepoName[pr.DependencyName]
		if !ok {
			log.Fatalf("Did not find dependency name '%s' in manifest %s",
				pr.DependencyName, pi.DescManifest.Path)
		}
		// All external dep targets are defined at the root
		l := label.New(repo, "", pr.ProductName)
		m := swift.NewModule(pr.ProductName, l)
		mi.AddModule(m)
	}
}
