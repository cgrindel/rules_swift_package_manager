package gazelle

import (
	"fmt"

	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swift"
)

const swiftLangName = "swift"

type swiftLang struct {
	language.BaseLang
}

// NewLanguage creates an instance of the Gazelle language for Swift.
func NewLanguage() language.Language {
	return &swiftLang{}
}

func (*swiftLang) Name() string { return swiftLangName }

func (*swiftLang) Loads() []rule.LoadInfo {
	panic("ApparentLoads should be called instead")
}

func (*swiftLang) ApparentLoads(moduleToApparentName func(string) string) []rule.LoadInfo {
	rulesSPM := moduleToApparentName("rules_swift_package_manager")
	if rulesSPM == "" {
		rulesSPM = "rules_swift_package_manager"
	}
	rulesSwift := moduleToApparentName("rules_swift")
	if rulesSwift == "" {
		rulesSwift = "build_bazel_rules_swift"
	}
	return []rule.LoadInfo{
		{
			Name: fmt.Sprintf("@%s//swift:%s.bzl", rulesSwift, swift.BinaryRuleKind),
			Symbols: []string{
				swift.BinaryRuleKind,
			},
		},
		{
			Name: fmt.Sprintf("@%s//swift:%s.bzl", rulesSwift, swift.LibraryRuleKind),
			Symbols: []string{
				swift.LibraryRuleKind,
			},
		},
		{
			Name: fmt.Sprintf("@%s//swift:%s.bzl", rulesSwift, swift.TestRuleKind),
			Symbols: []string{
				swift.TestRuleKind,
			},
		},
		{
			Name: fmt.Sprintf("@%s//proto:proto.bzl", rulesSwift),
			Symbols: []string{
				swift.ProtoLibraryRuleKind,
			},
		},
		{
			// Name: "@rules_swift_package_manager//swiftpkg:defs.bzl",
			Name: fmt.Sprintf("@%s//swiftpkg:defs.bzl", rulesSPM),
			Symbols: []string{
				swift.SwiftPkgRuleKind,
				swift.LocalSwiftPkgRuleKind,
			},
		},
	}
}
