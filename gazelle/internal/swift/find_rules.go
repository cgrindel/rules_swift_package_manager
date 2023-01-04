package swift

import "github.com/bazelbuild/bazel-gazelle/rule"

func findRulesByKind(rules []*rule.Rule, kind string) []*rule.Rule {
	var results []*rule.Rule
	for _, r := range rules {
		if r.Kind() == kind {
			results = append(results, r)
		}
	}
	return results
}
