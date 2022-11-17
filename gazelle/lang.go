package gazelle

import (
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
)

const swiftLangName = "swift"

var kindShared = rule.KindInfo{
	NonEmptyAttrs:  map[string]bool{"srcs": true, "deps": true},
	MergeableAttrs: map[string]bool{"srcs": true},
}

var kinds = map[string]rule.KindInfo{
	swift.LibraryRuleKind: kindShared,
	swift.BinaryRuleKind:  kindShared,
	swift.TestRuleKind:    kindShared,
}

var loads = []rule.LoadInfo{
	{
		Name: "@build_bazel_rules_swift//swift:swift.bzl",
		Symbols: []string{
			swift.LibraryRuleKind,
			swift.BinaryRuleKind,
			swift.TestRuleKind,
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
