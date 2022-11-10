package gazelle

import (
	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/repo"
	"github.com/bazelbuild/bazel-gazelle/resolve"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

const swiftName = "swift"

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

func NewLanguage() language.Language { return &swiftLang{} }

func (*swiftLang) Name() string { return swiftName }

func (*swiftLang) Kinds() map[string]rule.KindInfo { return kinds }

func (*swiftLang) Loads() []rule.LoadInfo { return loads }

func (l *swiftLang) Resolve(
	c *config.Config,
	ix *resolve.RuleIndex,
	rc *repo.RemoteCache,
	r *rule.Rule,
	imports interface{},
	from label.Label) {
}
