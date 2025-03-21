package reslog_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/resolve"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/reslog"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func newLabel(repo, pkg, name string) *label.Label {
	l := label.New(repo, pkg, name)
	return &l
}

func TestRuleResolution(t *testing.T) {
	from := label.New("", "path/to", "Foo")
	r := rule.NewRule(swift.LibraryRuleKind, from.Name)
	swiftImports := []string{
		"UIKit",
		"LocalA",
		"LocalB",
		"ExternalA",
		"Custom",
		"Unresolved",
	}
	rr := reslog.NewRuleResolution(from, r, swiftImports)
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
				newLabel("swiftpkg_awesome_repo", "path/to", "ExternalA"),
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
			nil,
			swift.HTTPArchivePkgIdentity,
			nil,
		),
	})
	rr.AddUnresolved("Unresolved")
	rr.AddDep(
		"//path/to:LocalA",
		"//path/to:LocalB",
		"@swiftpkg_awesome_repo//path/to:ExternalA",
		"@com_github_example_custom//:Custom",
	)

	expected := reslog.RuleResolutionSummary{
		Name: from.String(),
		Kind: swift.LibraryRuleKind,
		Imports: []string{
			"Custom",
			"ExternalA",
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
		ExtRes: reslog.ExternalResolutionSummary{
			Modules: []string{"ExternalA", "ExternalB"},
			Products: []reslog.Product{
				{"awesome-repo", "AwesomeProduct", "@swiftpkg_awesome_repo//path/to:ExternalA"},
			},
			Unresolved: []string{"Custom", "Unresolved"},
		},
		HTTPArchiveRes: []reslog.ModuleLabel{
			{"Custom", "@com_github_example_custom//:Custom"},
		},
		Unresolved: []string{"Unresolved"},
		Deps: []string{
			"//path/to:LocalA",
			"//path/to:LocalB",
			"@com_github_example_custom//:Custom",
			"@swiftpkg_awesome_repo//path/to:ExternalA",
		},
	}
	assert.Equal(t, expected, rr.Summary())
}
