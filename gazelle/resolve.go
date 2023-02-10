package gazelle

import (
	"log"
	"sort"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/repo"
	"github.com/bazelbuild/bazel-gazelle/resolve"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/reslog"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftcfg"
)

func (*swiftLang) Imports(_ *config.Config, r *rule.Rule, f *rule.File) []resolve.ImportSpec {
	if !swift.IsSwiftRuleKind(r.Kind()) {
		// Do not index
		return nil
	}
	moduleName := swift.ModuleName(r)
	if moduleName == "" {
		// Returning an empty list will cause the rule to be indexed
		return []resolve.ImportSpec{}
	}

	return []resolve.ImportSpec{{
		Lang: swiftLangName,
		Imp:  moduleName,
	}}
}

func (l *swiftLang) Resolve(
	c *config.Config,
	ix *resolve.RuleIndex,
	rc *repo.RemoteCache,
	r *rule.Rule,
	imports interface{},
	from label.Label) {

	sc := swiftcfg.GetSwiftConfig(c)
	di := sc.DependencyIndex
	pkgIdentities := di.DirectDepIdentities()
	swiftImports := imports.([]string)
	rr := reslog.NewRuleResolution(from, r, swiftImports)

	// Try to resolve to targets in this project.
	var deps []string
	addToDeps := func(lbl label.Label) {
		l := normalizeLabel(c.RepoName, lbl)
		deps = append(deps, l.String())
	}
	externalModules := make([]string, 0, len(swiftImports))
	for _, imp := range swiftImports {
		if swift.IsBuiltInModule(imp) {
			rr.AddBuiltin(imp)
			continue
		}
		findResults := ix.FindRulesByImportWithConfig(
			c, resolve.ImportSpec{Lang: swiftLangName, Imp: imp}, swiftLangName)
		if len(findResults) > 0 {
			addToDeps(findResults[0].Label)
			rr.AddLocal(imp, findResults)
		} else {
			externalModules = append(externalModules, imp)
		}
	}

	// Try to resolve to external Swift pacakage products
	resResult := di.ResolveModulesToProducts(externalModules, pkgIdentities)
	rr.AddExternal(externalModules, resResult)
	for lbl := range resResult.Products.Labels().Iterator().C {
		addToDeps(*lbl)
	}

	// If any module is still unresolved, look for modules defined in http_archive declarations.
	var unresolved []string
	for _, moduleName := range resResult.Unresolved {
		haModules := di.FindModules(moduleName, []string{swift.HTTPArchivePkgIdentity})
		if len(haModules) > 0 {
			addToDeps(*haModules[0].Label)
			rr.AddHTTPArchive(moduleName, haModules)
		} else {
			unresolved = append(unresolved, moduleName)
		}
	}

	if len(unresolved) > 0 {
		rr.AddUnresolved(unresolved...)
		log.Printf("Unable to find dependency labels for %v",
			strings.Join(resResult.Unresolved, ", "))
	}

	sort.Strings(deps)
	rr.AddDep(deps...)
	if len(deps) > 0 {
		r.SetAttr("deps", deps)
	}

	// Log the info. We do not have a callback to let us know when Gazelle is about the finish. So,
	// we will flush it immediately.
	sc.ResolutionLogger.Log(rr)
	sc.ResolutionLogger.Flush()
}

// Adjusts the label to not include the repo value if they are in the same repo.
func normalizeLabel(repoName string, l label.Label) label.Label {
	if repoName != l.Repo {
		return l
	}
	newL := label.New("", l.Pkg, l.Name)
	return newL
}
