package reslog_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/resolve"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/reslog"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func newLabel(repo, pkg, name string) *label.Label {
	l := label.New(repo, pkg, name)
	return &l
}

func TestRuleResolution(t *testing.T) {
	r := rule.NewRule(swift.LibraryRuleKind, "Foo")
	swiftImports := []string{
		"UIKit",
		"LocalA",
		"LocalB",
		"ExternalA",
		"ExternalB",
		"Custom",
		"Unresolved",
	}
	rr := reslog.NewRuleResolution(r, swiftImports)
	rr.AddBuiltin("UIKit")
	rr.AddLocal("LocalA", []resolve.FindResult{
		{Label: label.New("", "path/to", "LocalA")},
	})
	rr.AddLocal("LocalB", []resolve.FindResult{
		{Label: label.New("", "path/to", "LocalB")},
	})
	rr.AddExternal([]string{"ExternalA", "ExternalB"}, &swift.ModuleResolutionResult{
		Products: swift.Products{
			swift.NewProduct(
				"awesome-repo",
				"AwesomeProduct",
				swift.LibraryProductType,
				[]*label.Label{
					newLabel("swiftpkg_awesome_repo", "path/to", "ExternalA"),
					newLabel("swiftpkg_awesome_repo", "path/to", "ExternalB"),
				},
			),
		},
		Unresolved: []string{"Custom", "Unresolved"},
	})
	rr.AddHTTPArchive("Custom", swift.Modules{
		swift.NewModule(
			"Custom",
			"Custom",
			swiftpkg.SwiftSourceType,
			newLabel("com_github_example_custom", "", "Custom"),
			swift.HTTPArchivePkgIdentity,
			nil,
		),
	})
	rr.AddUnresolved("Unresolved")

	expected := reslog.RuleResolutionSummary{
		Name: "Foo",
		Kind: swift.LibraryRuleKind,
		Imports: []string{
			"Custom",
			"ExternalA",
			"ExternalB",
			"LocalA",
			"LocalB",
			"UIKit",
			"Unresolved",
		},
		Builtins: []string{"UIKit"},
		LocalRes: []reslog.ModuleLabel{
			{"LocalA", "//path/to:LocalA"},
			{"LocalB", "//path/to:LocalB"},
		},
		ExtRes: &reslog.ExternalResolutionSummary{
			Modules: []string{"ExternalA", "ExternalB"},
			Products: []reslog.Product{
				{"awesome-repo", "AwesomeProduct", []string{
					"@swiftpkg_awesome_repo//path/to:ExternalA",
					"@swiftpkg_awesome_repo//path/to:ExternalB",
				}},
			},
			Unresolved: []string{"Custom", "Unresolved"},
		},
		HTTPArchiveRes: []reslog.ModuleLabel{
			{"Custom", "@com_github_example_custom//:Custom"},
		},
		Unresolved: []string{"Unresolved"},
	}
	assert.Equal(t, expected, rr.Summary())
}
