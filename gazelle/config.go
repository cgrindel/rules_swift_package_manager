package gazelle

import (
	"flag"
	"log"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftbin"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
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
	mi := sc.ModuleIndex

	// GH021: Add flag so that the client can tell us which Swift to use.

	// Find the Swift executable
	if sc.SwiftBinPath, err = swiftbin.FindSwiftBinPath(); err != nil {
		return err
	}
	sb := sc.SwiftBin()

	if sc.GenFromPkgManifest {
		if pi, err := swiftpkg.NewPackageInfo(sb, c.RepoRoot); err != nil {
			return err
		} else if pi != nil {
			sc.PackageInfo = pi
			indexExtDepsInManifest(mi, pi)
		}
	}

	// All of the repository rules have been loaded into c.Repos. Process them.
	for _, r := range c.Repos {
		if err := mi.IndexRepoRule(r); err != nil {
			return err
		}
	}

	return nil
}

func indexExtDepsInManifest(mi *swift.ModuleIndex, pi *swiftpkg.PackageInfo) {
	var err error
	dump := pi.DumpManifest

	// Create a map of Swift external dep identity and Bazel repo name
	depIdentToBazelRepoName := make(map[string]string)
	for _, d := range dump.Dependencies {
		depIdentToBazelRepoName[d.Identity()], err = swift.RepoNameFromURL(d.URL())
		if err != nil {
			log.Fatalf("Failed to create repo name for %s: %w", d.Identity(), err)
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
