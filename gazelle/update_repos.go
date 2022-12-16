package gazelle

import (
	"log"
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
const swiftPkgBuildDirname = ".build"
const swiftPkgCheckoutsDirname = "checkouts"

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
	log.Fatal("No handler found for ImportRepos.")
	return language.ImportReposResult{}
}

func importReposFromPackageManifest(args language.ImportReposArgs) language.ImportReposResult {
	result := language.ImportReposResult{}
	c := args.Config
	sc := swiftcfg.GetSwiftConfig(c)
	sb := sc.SwiftBin()

	// Ensure that we have resolved and fetched the Swift package dependencies
	pkgDir := filepath.Dir(args.Path)
	if err := sb.ResolvePackage(pkgDir); err != nil {
		result.Error = err
		return result
	}

	// Get the package info for the workspace's Swift package
	pi, err := swiftpkg.NewPackageInfo(sb, pkgDir)
	if err != nil {
		result.Error = err
		return result
	}

	// Create a new module index on the swift config and populate it from the dependencies.
	mi := swift.NewModuleIndex()
	sc.ModuleIndex = mi

	// Collect product/module info for each of the dependencies
	// Key: External dependency identity
	// Value: Pointer to the dependency's package info
	depPkgInfoMap := make(map[string]*swiftpkg.PackageInfo)
	for _, dep := range pi.Dependencies {
		depDir := filepath.Join(
			pkgDir,
			swiftPkgBuildDirname,
			swiftPkgCheckoutsDirname,
			dep.Identity(),
		)
		if err != nil {
			result.Error = err
			return result
		}
		depPkgInfo, err := swiftpkg.NewPackageInfo(sb, depDir)
		if err != nil {
			result.Error = err
			return result
		}
		depPkgInfoMap[dep.Identity()] = depPkgInfo

		// Index the targets in the package
		repoName, err := swift.RepoNameFromDep(dep)
		if err != nil {
			result.Error = err
			return result
		}
		mi.IndexPkgInfo(depPkgInfo, repoName)
	}

	// Write the module index to a JSON file
	if err := sc.WriteModuleIndex(); err != nil {
		result.Error = err
		return result
	}

	resolvedPkgPath := filepath.Join(pkgDir, resolvedPkgBasename)
	return importReposFromResolvedPackage(depPkgInfoMap, sc.ModuleIndexPath, resolvedPkgPath)
}

func importReposFromResolvedPackage(
	depPkgInfoMap map[string]*swiftpkg.PackageInfo,
	miPath string,
	resolvedPkgPath string,
) language.ImportReposResult {
	result := language.ImportReposResult{}

	// Read the Package.resolved file
	b, err := os.ReadFile(resolvedPkgPath)
	if err != nil {
		result.Error = err
		return result
	}
	pins, err := spreso.NewPinsFromResolvedPackageJSON(b)
	if err != nil {
		result.Error = err
		return result
	}

	miBase := filepath.Base(miPath)
	result.Gen = make([]*rule.Rule, len(pins))
	for idx, p := range pins {
		result.Gen[idx], err = swift.RepoRuleFromPin(p, miBase)
		if err != nil {
			result.Error = err
			return result
		}
	}

	return result
}
