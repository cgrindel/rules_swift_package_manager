package gazelle

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/spreso"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swiftcfg"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swiftpkg"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/updmarker"
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

	// Create a build directory
	buildDir, err := os.MkdirTemp("", "rspm_build_dir")
	if err != nil {
		result.Error = err
		return result
	}
	defer os.RemoveAll(buildDir)

	// Ensure that we have resolved and fetched the Swift package dependencies
	pkgDir := filepath.Dir(args.Path)
	if err := sb.ResolvePackage(pkgDir, buildDir, sc.UpdatePkgsToLatest); err != nil {
		result.Error = err
		return result
	}

	// Get the package info for the workspace's Swift package
	pi, pierr := swiftpkg.NewPackageInfo(sb, pkgDir, buildDir)
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

	// Read the patches file
	var patches map[string]*swift.Patch
	if sc.PatchesPath != "" {
		patchesYAML, err := os.ReadFile(sc.PatchesPath)
		if err != nil {
			result.Error = err
			return result
		}
		patches, err = swift.NewPatchesFromYAML(patchesYAML)
		if err != nil {
			result.Error = err
			return result
		}
	} else {
		patches = make(map[string]*swift.Patch)
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
		depDir := swift.CodeDirForRemotePackage(buildDir, pin.PkgRef.Remote())
		depPkgInfo, dpierr := swiftpkg.NewPackageInfo(sb, depDir, "")
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
		depPkgInfo, err := swiftpkg.NewPackageInfo(sb, depDir, "")
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
		pkg, err := swift.NewPackageFromBazelRepo(
			bzlRepo, sc.DependencyIndexRel, pkgDir, c.RepoRoot, patches[bzlRepo.Identity])
		if err != nil {
			result.Error = err
			return result
		}
		di.AddPackage(pkg)
	}

	// Print information about language standards
	printLanguageStandardInfo(di.Packages())

	// Output a use_repo names for bzlmod.
	if err := writeBzlmodUseRepoNames(di, sc); err != nil {
		result.Error = err
		return result
	}

	// Output a bzlmod stanzas for bzlmod.
	if err := writeBzlmodStanzas(di, sc); err != nil {
		result.Error = err
		return result
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
		result.Gen[idx], err = swift.RepoRuleFromBazelRepo(
			bzlRepo,
			sc.DependencyIndexRel,
			pkgDir,
			c.RepoRoot,
			patches[bzlRepo.Identity],
		)
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

	// If we are generating the legacy dependency declarations, return the result.
	// Otherwise, return an empty result.
	if sc.GenerateSwiftDepsForWorkspace {
		return result
	}
	return language.ImportReposResult{}
}

func readResolvedPkgPins(resolvedPkgPath string) (map[string]*spreso.Pin, error) {
	pinsByIdentity := make(map[string]*spreso.Pin)
	// Check if the resolved file exists. This can happen if there are no pinned dependencies. In
	// other words, this can happen when there are no dependencies or only local package
	// dependencies.
	if _, err := os.Stat(resolvedPkgPath); err != nil {
		return pinsByIdentity, nil
	}
	b, err := os.ReadFile(resolvedPkgPath)
	if err != nil {
		return nil, err
	}
	pins, err := spreso.NewPinsFromResolvedPackageJSON(b)
	if err != nil {
		return nil, err
	}
	for _, p := range pins {
		pinsByIdentity[p.PkgRef.Identity] = p
	}
	return pinsByIdentity, nil
}

func printLanguageStandardInfo(pkgs []*swift.Package) {
	cLangStds := make(map[string][]string)
	cxxLangStds := make(map[string][]string)
	for _, pkg := range pkgs {
		if pkg.CLanguageStandard != "" {
			idents := cLangStds[pkg.CLanguageStandard]
			idents = append(idents, pkg.Identity)
			cLangStds[pkg.CLanguageStandard] = idents
		}
		if pkg.CxxLanguageStandard != "" {
			idents := cxxLangStds[pkg.CxxLanguageStandard]
			idents = append(idents, pkg.Identity)
			cxxLangStds[pkg.CxxLanguageStandard] = idents
		}
	}
	var outputLines []string
	if len(cLangStds) > 0 {
		for std, idents := range cLangStds {
			outputLines = append(outputLines,
				fmt.Sprintf("# Required by %s", strings.Join(idents, ", ")),
				fmt.Sprintf("build --copt='-std=%s'", std),
			)
		}
	}
	if len(cxxLangStds) > 0 {
		for std, idents := range cxxLangStds {
			outputLines = append(outputLines,
				fmt.Sprintf("# Required by %s", strings.Join(idents, ", ")),
				fmt.Sprintf("build --cxxopt='-std=%s'", std),
			)
		}
	}

	if len(outputLines) > 0 {
		preamble := `One or more of your Swift packages has defined language standard requirements.
Consider adding the following to your .bazelrc file:

`
		fmt.Println(preamble + strings.Join(outputLines, "\n"))
	}
}

func writeBzlmodUseRepoNames(di *swift.DependencyIndex, sc *swiftcfg.SwiftConfig) error {
	if !sc.UpdateBzlmodUseRepoNames {
		return nil
	}
	useRepoNames, err := swift.UseRepoNames(di)
	if err != nil {
		return err
	}
	finfo, err := os.Stat(sc.BazelModulePath)
	if err != nil {
		return err
	}
	data, err := os.ReadFile(sc.BazelModulePath)
	if err != nil {
		return err
	}
	updater := updmarker.NewUpdater(
		bzlmodUseRepoNamesUpdMarkerStart,
		bzlmodUseRepoNamesUpdMarkerEnd,
	)
	newContent, err := updater.UpdateString(string(data), useRepoNames, false)
	if err != nil {
		return err
	}
	return os.WriteFile(sc.BazelModulePath, []byte(newContent), finfo.Mode())
}

func writeBzlmodStanzas(di *swift.DependencyIndex, sc *swiftcfg.SwiftConfig) error {
	if !sc.PrintBzlmodStanzas && !sc.UpdateBzlmodStanzas {
		return nil
	}

	moduleDir := filepath.Dir(sc.BazelModulePath)
	bzlmodStanzas, err := swift.BzlmodStanzas(di, moduleDir, sc.DependencyIndexPath)

	if err != nil {
		return err
	}
	if sc.PrintBzlmodStanzas {
		if _, err = fmt.Printf("%s\n%s", bzlmodInstructions, bzlmodStanzas); err != nil {
			return err
		}
	}
	if sc.UpdateBzlmodStanzas {
		if err := updateBzlmodStanzas(bzlmodStanzas, sc.BazelModulePath); err != nil {
			return err
		}
	}
	return nil
}

func updateBzlmodStanzas(bzlmodStanzas, bazelModulePath string) error {
	finfo, err := os.Stat(bazelModulePath)
	if err != nil {
		return err
	}
	data, err := os.ReadFile(bazelModulePath)
	if err != nil {
		return err
	}
	updater := updmarker.NewUpdater(bzlmodStanzasUpdMarkerStart, bzlmodStanzasUpdMarkerEnd)
	newContent, err := updater.UpdateString(string(data), bzlmodStanzas, true)
	if err != nil {
		return err
	}
	return os.WriteFile(bazelModulePath, []byte(newContent), finfo.Mode())
}

const bzlmodUseRepoNamesUpdMarkerStart = "    # swift_deps bzlmod use_repo START\n"
const bzlmodUseRepoNamesUpdMarkerEnd = "    # swift_deps bzlmod use_repo END\n"

const bzlmodStanzasUpdMarkerStart = "# swift_deps START\n"
const bzlmodStanzasUpdMarkerEnd = "# swift_deps END\n"

const bzlmodInstructions = `If you have enabled bzlmod, add the following to your 'MODULE.bazel' file to
load your Swift dependencies:`
