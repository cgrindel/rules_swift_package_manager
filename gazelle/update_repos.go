package gazelle

import (
	"errors"
	"log"
	"os"
	"path/filepath"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
)

// language.RepoImporter Implementation

const resolvedPkgBasename = "Package.resolved"
const pkgManifestBasename = "Package.swift"

// var yamlExtensions = []string{".yaml", ".yml"}

func (*swiftLang) CanImport(path string) bool {
	return isResolvedPkg(path) || isPkgManifest(path)
	// return isResolvedPkg(path) || isPkgManifest(path) || isSwiftReqs(path)
}

func isResolvedPkg(path string) bool {
	return filepath.Base(path) == resolvedPkgBasename
}

func isPkgManifest(path string) bool {
	return filepath.Base(path) == pkgManifestBasename
}

// func isSwiftReqs(path string) bool {
// 	return stringslices.Contains(yamlExtensions, filepath.Ext(path))
// }

func (*swiftLang) ImportRepos(args language.ImportReposArgs) language.ImportReposResult {
	if isResolvedPkg(args.Path) {
		return importReposFromResolvedPackage(args.Path)
	} else if isPkgManifest(args.Path) {
		return importReposFromPackageManifest(args)
		// } else if isSwiftReqs(args.Path) {
		// 	return importReposFromSwiftReqs(args)
	}
	log.Fatal("No handler found for ImportRepos.")
	return language.ImportReposResult{}
}

func importReposFromResolvedPackage(resolvedPkgPath string) language.ImportReposResult {
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
		result.Gen[idx], err = swift.RepoRuleFromPin(p)
		if err != nil {
			result.Error = err
			return result
		}
	}

	return result
}

func importReposFromPackageManifest(args language.ImportReposArgs) language.ImportReposResult {
	result := language.ImportReposResult{}
	c := args.Config
	sc := swiftcfg.GetSwiftConfig(c)

	pkgDir := filepath.Dir(args.Path)
	if _, err := os.Stat(pkgDir); errors.Is(err, os.ErrNotExist) {
		sb := sc.SwiftBin()
		// Generate a resolved package
		if err := sb.ResolvePackage(pkgDir); err != nil {
			result.Error = err
			return result
		}
	} else if err != nil {
		result.Error = err
		return result
	}
	resolvedPkgPath := filepath.Join(pkgDir, resolvedPkgBasename)
	return importReposFromResolvedPackage(resolvedPkgPath)
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
