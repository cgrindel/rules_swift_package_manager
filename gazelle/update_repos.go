package gazelle

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
)

// language.RepoImporter Implementation

const resolvedPkgBasename = "Package.resolved"
const pkgManifestBasename = "Package.swift"

func (*swiftLang) CanImport(path string) bool {
	return isPkgManifest(path)
}

func isPkgManifest(path string) bool {
	return filepath.Base(path) == pkgManifestBasename
}

func (*swiftLang) ImportRepos(args language.ImportReposArgs) language.ImportReposResult {
	if isPkgManifest(args.Path) {
		return importReposFromPackageManifest(args)
	}
	return language.ImportReposResult{
		Error: fmt.Errorf("no ImportRepos handler found for %v", args.Path),
	}
}

func importReposFromPackageManifest(args language.ImportReposArgs) language.ImportReposResult {
	result := language.ImportReposResult{}
	c := args.Config
	sc := swiftcfg.GetSwiftConfig(c)
	sb := sc.SwiftBin()

	// Ensure that we have resolved and fetched the Swift package dependencies
	pkgDir := filepath.Dir(args.Path)
	if err := sb.ResolvePackage(pkgDir, sc.UpdatePkgsToLatest); err != nil {
		result.Error = err
		return result
	}

	// Get the package info for the workspace's Swift package
	pi, pierr := swiftpkg.NewPackageInfo(sb, pkgDir)
	if pierr != nil {
		result.Error = pierr
		return result
	}

	// Read the Package.resolved file
	resolvedPkgPath := filepath.Join(pkgDir, resolvedPkgBasename)
	pinsByIdentity, pbierr := readResolvedPkgPins(resolvedPkgPath)
	if pbierr != nil {
		result.Error = pbierr
		return result
	}

	// Create a new module index on the swift config and populate it from the dependencies.
	di := swift.NewDependencyIndex()
	sc.DependencyIndex = di

	// Store the direct deps
	di.AddDirectDependency(pi.Dependencies.Identities()...)

	// Need to collect all of the direct deps and their transitive deps. These can be remote deps,
	// which will have a spreso.Pin, and some will be local which will not have a spreso.Pin.
	bzlReposByIdentity := make(map[string]*swift.BazelRepo)
	for identity, pin := range pinsByIdentity {
		depDir := swift.CodeDirForRemotePackage(pkgDir, pin.PkgRef.Remote())
		depPkgInfo, dpierr := swiftpkg.NewPackageInfo(sb, depDir)
		if dpierr != nil {
			result.Error = dpierr
			return result
		}
		bzlRepo, brerr := swift.NewBazelRepo(identity, depPkgInfo, pin)
		if brerr != nil {
			result.Error = brerr
			return result
		}
		bzlReposByIdentity[bzlRepo.Identity] = bzlRepo
	}
	for _, dep := range pi.Dependencies {
		identity := dep.Identity()
		if _, ok := bzlReposByIdentity[identity]; ok {
			continue
		}
		if dep.FileSystem == nil {
			result.Error = fmt.Errorf("expected the dependency %v to be a local package", identity)
			return result
		}
		depDir := swift.CodeDirForLocalPackage(pkgDir, dep.FileSystem.Path)
		depPkgInfo, err := swiftpkg.NewPackageInfo(sb, depDir)
		if err != nil {
			result.Error = err
			return result
		}
		bzlRepo, err := swift.NewBazelRepo(identity, depPkgInfo, nil)
		if err != nil {
			result.Error = err
			return result
		}
		bzlReposByIdentity[bzlRepo.Identity] = bzlRepo
	}

	// Index all of the Bazel Repos
	for _, bzlRepo := range bzlReposByIdentity {
		if err := di.IndexBazelRepo(bzlRepo); err != nil {
			result.Error = err
			return result
		}
	}

	// Write the module index to a JSON file
	if err := sc.WriteDependencyIndex(); err != nil {
		result.Error = err
		return result
	}

	// Generate the repository rules from the Bazel Repos
	repoUsage := make(map[string]bool)
	result.Gen = make([]*rule.Rule, len(bzlReposByIdentity))
	idx := 0
	for _, bzlRepo := range bzlReposByIdentity {
		repoUsage[bzlRepo.Name] = true
		var err error
		result.Gen[idx], err = swift.RepoRuleFromBazelRepo(bzlRepo, sc.DependencyIndexRel, pkgDir)
		if err != nil {
			result.Error = err
			return result
		}
		idx++
	}

	if args.Prune {
		// Remove any existing repos that are no longer used.
		for _, r := range c.Repos {
			kind := r.Kind()
			switch kind {
			case swift.SwiftPkgRuleKind, swift.LocalSwiftPkgRuleKind:
				if name := r.Name(); !repoUsage[name] {
					result.Empty = append(result.Empty, rule.NewRule(kind, name))
				}
			}
		}
	}

	return result
}

func readResolvedPkgPins(resolvedPkgPath string) (map[string]*spreso.Pin, error) {
	b, err := os.ReadFile(resolvedPkgPath)
	if err != nil {
		return nil, err
	}
	pins, err := spreso.NewPinsFromResolvedPackageJSON(b)
	if err != nil {
		return nil, err
	}
	pinsByIdentity := make(map[string]*spreso.Pin)
	for _, p := range pins {
		pinsByIdentity[p.PkgRef.Identity] = p
	}
	return pinsByIdentity, nil
}
