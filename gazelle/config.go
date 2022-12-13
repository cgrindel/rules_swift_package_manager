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

// func findExternalDepsInWorkspace(c *config.Config, mi *swift.ModuleIndex, repoRoot string) error {
// 	wkspFilePath := wspace.FindWORKSPACEFile(repoRoot)
// 	wkspFile, err := rule.LoadWorkspaceFile(wkspFilePath, "")
// 	if err != nil {
// 		return fmt.Errorf("failed to load WORKSPACE file %v: %w", wkspFilePath, err)
// 	}
// 	// DEBUG BEGIN
// 	log.Printf("*** CHUCK: findExternalDepsInWorkspace len(c.Repos): %+#v", len(c.Repos))
// 	log.Printf("*** CHUCK: findExternalDepsInWorkspace c.Repos: ")
// 	for idx, item := range c.Repos {
// 		log.Printf("*** CHUCK %d: %+#v", idx, item)
// 	}
// 	// DEBUG END
// 	// repoRules, err := findRepoRulesInWorkspaceFile(c.RepoRoot, wkspFile)
// 	// if err != nil {
// 	// 	return err
// 	// }
// 	// c.Repos = append(c.Repos, repoRules...)
// 	// TODO(chuck): Add all modules from swift_package repo rules to module index.

// 	if err := processHTTPArchives(mi, wkspFile); err != nil {
// 		return err
// 	}

// 	// DEBUG BEGIN
// 	log.Printf("*** findExternalDepsInWorkspace CHUCK: c.Repos: ")
// 	for idx, item := range c.Repos {
// 		log.Printf("*** CHUCK %d: %+#v", idx, item)
// 	}
// 	// DEBUG END
// 	return nil
// }

// func findRepoRulesInWorkspaceFile(repoRoot string, wkspFile *rule.File) ([]*rule.Rule, error) {
// 	// Check for any swift_package declarations in the workspace file.
// 	repoRules := findSwiftPkgRules(wkspFile.Rules)

// 	// DEBUG BEGIN
// 	log.Printf("*** CHUCK: findRepoRulesInWorkspaceFile repoRules: ")
// 	for idx, item := range repoRules {
// 		log.Printf("*** CHUCK %d: %+#v", idx, item)
// 	}
// 	// DEBUG END

// 	// // Check for any swift_package declarations in a file declared by repository_macro
// 	// for _, d := range wkspFile.Directives {
// 	// 	switch d.Key {
// 	// 	case "repository_macro":
// 	// 		parsed, err := repo.ParseRepositoryMacroDirective(d.Value)
// 	// 		if err != nil {
// 	// 			return nil, err
// 	// 		}
// 	// 		rulesFromMacros, err := findExtDepsInRepoMacro(repoRoot, parsed)
// 	// 		if err != nil {
// 	// 			return nil, err
// 	// 		}
// 	// 		repoRules = append(repoRules, rulesFromMacros...)
// 	// 	}
// 	// }

// 	return repoRules, nil
// }

// func findExtDepsInRepoMacro(repoRoot string, rm *repo.RepoMacro) ([]*rule.Rule, error) {
// 	macroPath := filepath.Join(repoRoot, rm.Path)
// 	// DEBUG BEGIN
// 	log.Printf("*** CHUCK: findExtDepsInRepoMacro macroPath: %+#v", macroPath)
// 	// DEBUG END
// 	macroFile, err := rule.LoadMacroFile(macroPath, "", rm.DefName)
// 	if err != nil {
// 		return nil, err
// 	}
// 	return findSwiftPkgRules(macroFile.Rules), nil
// }

// func findSwiftPkgRules(rules []*rule.Rule) []*rule.Rule {
// 	var repoRules []*rule.Rule
// 	for _, r := range rules {
// 		if r.Kind() == swift.SwiftPkgRuleKind {
// 			repoRules = append(repoRules, r)
// 		}
// 	}
// 	return repoRules
// }

// func processHTTPArchives(mi *swift.ModuleIndex, wkspFile *rule.File) error {
// 	archives, err := swift.NewHTTPArchivesFromWkspFile(wkspFile)
// 	if err != nil {
// 		return fmt.Errorf(
// 			"failed to retrieve archives from workspace file %v: %w",
// 			wkspFile.Path,
// 			err,
// 		)
// 	}
// 	for _, archive := range archives {
// 		mi.AddModules(archive.Modules...)
// 	}
// 	return nil
// }

func indexExtDepsInManifest(mi *swift.ModuleIndex, pi *swiftpkg.PackageInfo) {
	var err error
	dump := pi.DumpManifest

	// Create a map of Swift external dep identity and Bazel repo name
	depIdentToBazelRepoName := make(map[string]string)
	for _, d := range dump.Dependencies {
		depIdentToBazelRepoName[d.Name], err = swift.RepoNameFromURL(d.URL)
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
