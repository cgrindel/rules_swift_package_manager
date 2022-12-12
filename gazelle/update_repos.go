package gazelle

import (
	"fmt"
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

// var yamlExtensions = []string{".yaml", ".yml"}

func (*swiftLang) CanImport(path string) bool {
	return isPkgManifest(path)
	// return isResolvedPkg(path) || isPkgManifest(path) || isSwiftReqs(path)
}

// func isResolvedPkg(path string) bool {
// 	return filepath.Base(path) == resolvedPkgBasename
// }

func isPkgManifest(path string) bool {
	return filepath.Base(path) == pkgManifestBasename
}

// func isSwiftReqs(path string) bool {
// 	return stringslices.Contains(yamlExtensions, filepath.Ext(path))
// }

func (*swiftLang) ImportRepos(args language.ImportReposArgs) language.ImportReposResult {
	if isPkgManifest(args.Path) {
		return importReposFromPackageManifest(args)
		// } else if isSwiftReqs(args.Path) {
		// 	return importReposFromSwiftReqs(args)
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

	// Collect product/module info for each of the dependencies
	// Key: External dependency identity
	// Value: Pointer to the dependency's package info
	depPkgInfoMap := make(map[string]*swiftpkg.PackageInfo)
	for _, dep := range pi.DumpManifest.Dependencies {
		depDir := filepath.Join(pkgDir, swiftPkgBuildDirname, swiftPkgCheckoutsDirname, dep.Name)
		if err != nil {
			result.Error = err
			return result
		}
		depPkgInfo, err := swiftpkg.NewPackageInfo(sb, depDir)
		if err != nil {
			result.Error = err
			return result
		}
		depPkgInfoMap[dep.Name] = depPkgInfo
	}

	resolvedPkgPath := filepath.Join(pkgDir, resolvedPkgBasename)
	return importReposFromResolvedPackage(depPkgInfoMap, resolvedPkgPath)
}

// func collectModuleInfoFromSwiftPkg(, pkgDir string, repoName string) error {
// 	// DEBUG BEGIN
// 	log.Printf("*** CHUCK: collectModuleInfoFromSwiftPkg repoName: %+#v", repoName)
// 	log.Printf("*** CHUCK: collectModuleInfoFromSwiftPkg pkgDir: %+#v", pkgDir)
// 	// DEBUG END
// 	return nil
// }

func importReposFromResolvedPackage(
	depPkgInfoMap map[string]*swiftpkg.PackageInfo,
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

	result.Gen = make([]*rule.Rule, len(pins))
	for idx, p := range pins {
		depPkgInfo, ok := depPkgInfoMap[p.PkgRef.Identity]
		if !ok {
			result.Error = fmt.Errorf("did not find package info for %s dep", p.PkgRef.Identity)
			return result
		}
		targets, err := depPkgInfo.ExportedTargets()
		if err != nil {
			result.Error = err
			return result
		}
		// Create a map of the module names (key) to relative Bazel label (value)
		modules := make(map[string]string)
		for _, t := range targets {
			modules[t.C99name] = swift.BazelLabelFromTarget("", t)
		}

		result.Gen[idx], err = swift.RepoRuleFromPin(p, modules)
		if err != nil {
			result.Error = err
			return result
		}
	}

	return result
}

// func importReposFromSwiftReqs(args language.ImportReposArgs) language.ImportReposResult {
// 	result := language.ImportReposResult{}
// 	c := args.Config
// 	sc := swiftcfg.GetSwiftConfig(c)

// 	b, err := os.ReadFile(args.Path)
// 	if err != nil {
// 		result.Error = err
// 		return result
// 	}
// 	reqs, err := spreq.NewRequirementsFromYAML(b)
// 	if err != nil {
// 		result.Error = err
// 		return result
// 	}
// 	pkgDir := filepath.Dir(args.Path)
// 	err = spreq.WritePkgManifest(reqs, pkgDir)
// 	if err != nil {
// 		result.Error = err
// 		return result
// 	}
// 	sb := sc.SwiftBin()
// 	err = sb.Resolve(pkgDir)
// 	if err != nil {
// 		result.Error = err
// 		return result
// 	}

// 	resolvedPkgPath := filepath.Join(pkgDir, resolvedPkgBasename)
// 	return importReposFromResolvedPackage(resolvedPkgPath)
// }
