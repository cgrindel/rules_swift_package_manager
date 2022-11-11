package gazelle

import (
	"log"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

const languageName = "swift"

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
	// DEBUG BEGIN
	log.Printf("*** CHUCK: NewLanguage START")
	// DEBUG END
	return &swiftLang{}
}

func (*swiftLang) Name() string { return languageName }

func (*swiftLang) Kinds() map[string]rule.KindInfo {
	// // DEBUG BEGIN
	// log.Printf("*** CHUCK: Kinds kinds: %+#v", kinds)
	// // DEBUG END
	return kinds
}

func (*swiftLang) Loads() []rule.LoadInfo {
	// // DEBUG BEGIN
	// log.Printf("*** CHUCK: Loads loads: %+#v", loads)
	// // DEBUG END
	return loads
}

// func (sl *swiftLang) RegisterFlags(fs *flag.FlagSet, cmd string, c *config.Config) {
// 	// DEBUG BEGIN
// 	log.Printf("*** CHUCK: RegisterFlags cmd: %+#v", cmd)
// 	log.Printf("*** CHUCK: RegisterFlags c: %+#v", c)
// 	// DEBUG END
// }

// type swiftModuleCollector struct {
// 	ModuleFiles map[string][]string
// }

// func (l *swiftLang) Resolve(
// 	c *config.Config,
// 	ix *resolve.RuleIndex,
// 	rc *repo.RemoteCache,
// 	r *rule.Rule,
// 	imports interface{},
// 	from label.Label) {
// 	// DEBUG BEGIN
// 	log.Printf("*** CHUCK: Resolve ix: %+#v", ix)
// 	log.Printf("*** CHUCK: Resolve rc: %+#v", rc)
// 	log.Printf("*** CHUCK: Resolve r: %+#v", r)
// 	log.Printf("*** CHUCK: Resolve imports: %+#v", imports)
// 	log.Printf("*** CHUCK: Resolve from: %+#v", from)
// 	// DEBUG END
// }

// func (*swiftLang) Configure(c *config.Config, rel string, f *rule.File) {
// 	// // DEBUG BEGIN
// 	// // log.Printf("*** CHUCK: Configure c: %+#v", c)
// 	// log.Printf("*** CHUCK: Configure c.Langs: %+#v", c.Langs)
// 	// log.Printf("*** CHUCK: Configure rel: %+#v", rel)
// 	// log.Printf("*** CHUCK: Configure f: %v", f)
// 	// // DEBUG END
// }

// // Imports returns a list of ImportSpecs that can be used to import the rule
// // r. This is used to populate RuleIndex.
// //
// // If nil is returned, the rule will not be indexed. If any non-nil slice is
// // returned, including an empty slice, the rule will be indexed.
// func (*swiftLang) Imports(c *config.Config, r *rule.Rule, f *rule.File) []resolve.ImportSpec {
// 	// DEBUG BEGIN
// 	log.Printf("*** CHUCK: Imports r: %+#v", r)
// 	log.Printf("*** CHUCK: Imports f: %+#v", f)
// 	// DEBUG END
// 	srcs := r.AttrStrings("srcs")
// 	imports := make([]resolve.ImportSpec, 0, len(srcs))
//
// 	for _, src := range srcs {
// 		spec := resolve.ImportSpec{
// 			// Lang is the language in which the import string appears (this should
// 			// match Resolver.Name).
// 			Lang: languageName,
// 			// Imp is an import string for the library.
// 			Imp: fmt.Sprintf("//%s:%s", f.Pkg, src),
// 		}
//
// 		imports = append(imports, spec)
// 	}
//
// 	return imports
// }
