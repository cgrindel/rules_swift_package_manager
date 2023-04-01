package gazelle

import (
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
)

const swiftLangName = "swift"

var loads = []rule.LoadInfo{
	{
		Name: "@build_bazel_rules_swift//swift:swift.bzl",
		Symbols: []string{
			swift.LibraryRuleKind,
			swift.BinaryRuleKind,
			swift.TestRuleKind,
		},
	},
	{
		Name: "@rules_swift_package_manager//swiftpkg:defs.bzl",
		Symbols: []string{
			swift.SwiftPkgRuleKind,
			swift.LocalSwiftPkgRuleKind,
		},
	},
}

type swiftLang struct {
	language.BaseLang
}

// NewLanguage creates an instance of the Gazelle language for Swift.
func NewLanguage() language.Language {
	return &swiftLang{}
}

func (*swiftLang) Name() string { return swiftLangName }

func (*swiftLang) Loads() []rule.LoadInfo {
	return loads
}
