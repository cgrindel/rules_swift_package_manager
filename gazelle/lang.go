package gazelle

import (
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

const swiftLangName = "swift"

const swiftLibraryRule = "swift_library"
const swiftBinaryRule = "swift_binary"
const swiftTestRule = "swift_test"

var kindShared = rule.KindInfo{
	NonEmptyAttrs:  map[string]bool{"srcs": true, "deps": true},
	MergeableAttrs: map[string]bool{"srcs": true},
}

var kinds = map[string]rule.KindInfo{
	swiftLibraryRule: kindShared,
	swiftBinaryRule:  kindShared,
	swiftTestRule:    kindShared,
}

var loads = []rule.LoadInfo{
	{
		Name: "@build_bazel_rules_swift//swift:swift.bzl",
		Symbols: []string{
			swiftLibraryRule,
			swiftBinaryRule,
			swiftTestRule,
		},
	},
}

type swiftLang struct {
	language.BaseLang
}

func NewLanguage() language.Language {
	return &swiftLang{}
}

func (*swiftLang) Name() string { return swiftLangName }

func (*swiftLang) Kinds() map[string]rule.KindInfo {
	return kinds
}

func (*swiftLang) Loads() []rule.LoadInfo {
	return loads
}

// // Imports returns a list of ImportSpecs that can be used to import the rule
// // r. This is used to populate RuleIndex.
// //
// // If nil is returned, the rule will not be indexed. If any non-nil slice is
// // returned, including an empty slice, the rule will be indexed.
// func (*swiftLang) Imports(c *config.Config, r *rule.Rule, f *rule.File) []resolve.ImportSpec {
// 	srcs := r.AttrStrings("srcs")
// 	imports := make([]resolve.ImportSpec, 0, len(srcs))
//
// 	for _, src := range srcs {
// 		spec := resolve.ImportSpec{
// 			// Lang is the language in which the import string appears (this should
// 			// match Resolver.Name).
// 			Lang: swiftLangName,
// 			// Imp is an import string for the library.
// 			Imp: fmt.Sprintf("//%s:%s", f.Pkg, src),
// 		}
//
// 		imports = append(imports, spec)
// 	}
//
// 	return imports
// }
