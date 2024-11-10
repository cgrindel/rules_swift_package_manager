package swift

import (
	"fmt"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/rule"
)

// Determines which Swift rule should be used to build the sources. If the build file contains a
// rule kind that ends in _test except swift_test, we assume that it will consume a swift_library.
func buildRuleForTestSrcs(buildFile *rule.File, name, moduleName string) *rule.Rule {
	var libName string
	testKind := TestRuleKind
	testName := name

	// Look for existing test rules and libraries
	if buildFile != nil {
		for _, r := range buildFile.Rules {
			rkind := r.Kind()
			if strings.HasSuffix(rkind, "_test") {
				testKind = rkind
				testName = r.Name()
			} else if rkind == LibraryRuleKind {
				libName = r.Name()
			}
		}
	}

	// Decide what type of Swift rule to generate
	if testKind == TestRuleKind {
		return rule.NewRule(TestRuleKind, testName)
	}

	// Create a testonly library
	if libName == "" {
		libName = fmt.Sprintf("%sLib", moduleName)
	}
	r := rule.NewRule(LibraryRuleKind, libName)
	r.SetAttr("testonly", true)
	return r
}
