package gazelle

import (
	"log"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/repo"
	"github.com/bazelbuild/bazel-gazelle/resolve"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
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

	mi := getSwiftConfig(c).moduleIndex
	swiftImports := imports.([]string)

	var deps []string
	for _, imp := range swiftImports {
		if swift.IsBuiltInModule(imp) {
			continue
		}

		findResults := ix.FindRulesByImportWithConfig(
			c, resolve.ImportSpec{Lang: swiftLangName, Imp: imp}, swiftLangName)
		if len(findResults) > 0 {
			l := findResults[0].Label
			deps = append(deps, l.String())
		} else if m := mi.Resolve(c.RepoName, imp); m != nil {
			deps = append(deps, m.Label.String())
		} else {
			log.Printf("Unable to find dependency label for %v", imp)
		}
	}

	if len(deps) > 0 {
		r.SetAttr("deps", deps)
	}
}
