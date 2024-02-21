package gazelle

import (
	"log"
	"path/filepath"
	"sort"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/repo"
	"github.com/bazelbuild/bazel-gazelle/resolve"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/reslog"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swiftcfg"
)

func (*swiftLang) Imports(_ *config.Config, r *rule.Rule, f *rule.File) []resolve.ImportSpec {
	if !swift.IsSwiftRuleKind(r.Kind()) {
		// Do not index
		return nil
	}

	importSpecs := []resolve.ImportSpec{}

	// If this is a swift_proto_library, create a swift import spec for each proto path
	// supplied by the library.
	if r.Kind() == swift.ProtoLibraryRuleKind {
		swiftProtoPackage, ok := r.PrivateAttr(swift.SwiftProtoPackageKey).(swift.SwiftProtoPackage)
		if ok {
			for protoFileName := range swiftProtoPackage.ProtoPackage.Files {
				protoPath := filepath.Join(swiftProtoPackage.Rel, protoFileName)
				importSpecs = append(importSpecs, resolve.ImportSpec{
					Lang: swiftLangName,
					Imp:  protoPath,
				})
			}
		} else {
			log.Printf("Rule was missing private attribute for swift.SwiftProtoPackageKey: %v", r)
		}
	}

	// Create the module name import spec if it was set:
	moduleName := swift.ModuleName(r)
	if moduleName == "" {
		// Returning an empty list will cause the rule to be indexed
		return importSpecs
	}
	importSpecs = append(importSpecs, resolve.ImportSpec{
		Lang: swiftLangName,
		Imp:  moduleName,
	})

	return importSpecs
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

	var deps []string
	addToDeps := func(lbl label.Label) {
		l := normalizeLabel(c.RepoName, lbl)
		deps = append(deps, l.String())
	}

	// Try to resolve to targets in this project.
	externalModules := make([]string, 0, len(swiftImports))
	for _, imp := range swiftImports {
		importSpec := resolve.ImportSpec{Lang: swiftLangName, Imp: imp}
		if l, ok := resolve.FindRuleWithOverride(c, importSpec, "swift"); ok {
			addToDeps(l)
			rr.AddLocal(imp, []resolve.FindResult{
				{
					Label:  l,
					Embeds: nil, // TODO: This might be broken -- not sure what to put here.
				}},
			)
			continue
		}
		findResults := ix.FindRulesByImportWithConfig(
			c, importSpec, swiftLangName)
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

	// If any module is still unresolved, look for modules defined in http_archive declarations or built-in modules.
	var unresolved []string
	for _, moduleName := range resResult.Unresolved {
		haModules := di.FindModules(moduleName, []string{swift.HTTPArchivePkgIdentity})
		if len(haModules) > 0 {
			addToDeps(*haModules[0].Label)
			rr.AddHTTPArchive(moduleName, haModules)
		} else if swift.IsBuiltInFramework(moduleName) || swift.IsBuiltInSwiftModule(moduleName) {
			rr.AddBuiltin(moduleName)
		} else {
			unresolved = append(unresolved, moduleName)
		}
	}

	if len(unresolved) > 0 {
		rr.AddUnresolved(unresolved...)
		log.Printf("Unable to find dependency labels for %v",
			strings.Join(unresolved, ", "))
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
