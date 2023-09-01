package gazelle

import (
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/gazelle/internal/swift"
)

var kinds = map[string]rule.KindInfo{
	swift.BinaryRuleKind: rule.KindInfo{
		MatchAny: true,
		NonEmptyAttrs: map[string]bool{
			"srcs": true,
			"deps": true,
		},
		MergeableAttrs: map[string]bool{
			"copts":         true,
			"defines":       true,
			"linkopts":      true,
			"malloc":        true,
			"srcs":          true,
			"swiftc_inputs": true,
		},
		// This ensures that the deps attribute is updated properly if a dependency disappears.
		ResolveAttrs: map[string]bool{"deps": true},
	},
	swift.LibraryRuleKind: rule.KindInfo{
		MatchAttrs: []string{"module_name"},
		NonEmptyAttrs: map[string]bool{
			"srcs":         true,
			"deps":         true,
			"private_deps": true,
		},
		MergeableAttrs: map[string]bool{
			"alwayslink":            true,
			"copts":                 true,
			"defines":               true,
			"generated_header_name": true,
			"generates_header":      true,
			"linkopts":              true,
			"linkstatic":            true,
			"srcs":                  true,
			"swiftc_inputs":         true,
		},
		// This ensures that the deps attribute is updated properly if a dependency disappears.
		ResolveAttrs: map[string]bool{"deps": true},
	},
	swift.ProtoLibraryRuleKind: rule.KindInfo{
		MatchAttrs: []string{"module_name"},
		NonEmptyAttrs: map[string]bool{
			"deps": true,
		},
		MergeableAttrs: map[string]bool{},
		// This ensures that the deps attribute is updated properly if a dependency disappears.
		ResolveAttrs: map[string]bool{"deps": true},
	},
	swift.GRPCLibraryRuleKind: rule.KindInfo{
		MatchAttrs: []string{"module_name"},
		NonEmptyAttrs: map[string]bool{
			"srcs":   true,
			"deps":   true,
			"flavor": true,
		},
		MergeableAttrs: map[string]bool{
			"srcs": true,
		},
		// This ensures that the deps attribute is updated properly if a dependency disappears.
		ResolveAttrs: map[string]bool{"deps": true},
	},
	swift.TestRuleKind: rule.KindInfo{
		MatchAny: true,
		NonEmptyAttrs: map[string]bool{
			"srcs": true,
			"deps": true,
		},
		MergeableAttrs: map[string]bool{
			"copts":         true,
			"defines":       true,
			"env":           true,
			"linkopts":      true,
			"malloc":        true,
			"srcs":          true,
			"swiftc_inputs": true,
		},
		// This ensures that the deps attribute is updated properly if a dependency disappears.
		ResolveAttrs: map[string]bool{"deps": true},
	},
	swift.SwiftPkgRuleKind: rule.KindInfo{
		MatchAttrs: []string{
			"remote",
		},
		NonEmptyAttrs: map[string]bool{
			"remote": true,
		},
		MergeableAttrs: map[string]bool{
			"branch":                    true,
			"commit":                    true,
			"dependencies_index":        true,
			"init_submodules":           true,
			"patch_args":                true,
			"patch_cmds":                true,
			"patch_cmds_win":            true,
			"patch_tool":                true,
			"patches":                   true,
			"recursive_init_submodules": true,
			"remote":                    true,
			"shallow_since":             true,
			"tag":                       true,
			"verbose":                   true,
		},
	},
	swift.LocalSwiftPkgRuleKind: rule.KindInfo{
		MatchAttrs: []string{
			"path",
		},
		NonEmptyAttrs: map[string]bool{
			"path": true,
		},
		MergeableAttrs: map[string]bool{
			"dependencies_index": true,
		},
	},
}

func (*swiftLang) Kinds() map[string]rule.KindInfo {
	return kinds
}
