package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestNewHTTPArchiveFromRule(t *testing.T) {
	repoRoot := "/path/to/project"
	f, err := rule.LoadWorkspaceData("/path/to/project/WORKSPACE", "",
		[]byte(sampleWorkspaceFileContent))
	assert.NoError(t, err)

	assert.Len(t, f.Rules, 3)

	actual, err := swift.NewHTTPArchiveFromRule(f.Rules[0], repoRoot)
	assert.NoError(t, err)
	assert.Nil(t, actual)

	actual, err = swift.NewHTTPArchiveFromRule(f.Rules[1], repoRoot)
	assert.NoError(t, err)
	expected := swift.NewHTTPArchive(
		"com_github_apple_swift_collections",
		[]*swift.Module{
			swift.NewModuleFromLabelStruct(
				"Collections",
				"Collections",
				swiftpkg.SwiftSourceType,
				label.New("com_github_apple_swift_collections", "", "Collections"),
				swift.HTTPArchivePkgIdentity,
				nil,
			),
			swift.NewModuleFromLabelStruct(
				"DequeModule",
				"DequeModule",
				swiftpkg.SwiftSourceType,
				label.New("com_github_apple_swift_collections", "", "DequeModule"),
				swift.HTTPArchivePkgIdentity,
				nil,
			),
			swift.NewModuleFromLabelStruct(
				"OrderedCollections",
				"OrderedCollections",
				swiftpkg.SwiftSourceType,
				label.New("com_github_apple_swift_collections", "", "OrderedCollections"),
				swift.HTTPArchivePkgIdentity,
				nil,
			),
		},
	)
	assert.Equal(t, expected, actual)

	actual, err = swift.NewHTTPArchiveFromRule(f.Rules[2], repoRoot)
	assert.NoError(t, err)
	expected = swift.NewHTTPArchive(
		"com_github_apple_swift_argument_parser",
		[]*swift.Module{
			swift.NewModuleFromLabelStruct(
				"ArgumentParser",
				"ArgumentParser",
				swiftpkg.SwiftSourceType,
				label.New("com_github_apple_swift_argument_parser", "", "ArgumentParser"),
				swift.HTTPArchivePkgIdentity,
				nil,
			),
			swift.NewModuleFromLabelStruct(
				"ArgumentParserToolInfo",
				"ArgumentParserToolInfo",
				swiftpkg.SwiftSourceType,
				label.New("com_github_apple_swift_argument_parser", "", "ArgumentParserToolInfo"),
				swift.HTTPArchivePkgIdentity,
				nil,
			),
		},
	)
	assert.Equal(t, expected, actual)
}

const sampleWorkspaceFileContent = `
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
# This http_archive should be ignored.
http_archive(
    name = "build_bazel_rules_swift",
    sha256 = "51efdaf85e04e51174de76ef563f255451d5a5cd24c61ad902feeadafc7046d9",
    url = "https://github.com/bazelbuild/rules_swift/releases/download/1.2.0/rules_swift.1.2.0.tar.gz",
)
# This http_archive should be processed.
http_archive(
    name = "com_github_apple_swift_collections",
    build_file_content = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
swift_library(
    name = "Collections",
    srcs = glob(["Sources/Collections/**/*.swift"]),
    visibility = ["//visibility:public"],
)
swift_library(
    name = "DequeModule",
    srcs = glob(["Sources/DequeModule/**/*.swift"]),
    visibility = ["//visibility:public"],
)
swift_library(
    name = "OrderedCollections",
    srcs = glob(["Sources/OrderedCollections/**/*.swift"]),
    visibility = ["//visibility:public"],
)
""",
    sha256 = "b18c522aff4241160f60bcd0695702657c7862512c994c260a7d63f15a8450d8",
    strip_prefix = "swift-collections-1.0.2",
    url = "https://github.com/apple/swift-collections/archive/refs/tags/1.0.2.tar.gz",
)
# This http_archive should be processed.
http_archive(
    name = "com_github_apple_swift_argument_parser",
    build_file_content = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
swift_library(
    name = "ArgumentParser",
    srcs = glob(["Sources/ArgumentParser/**/*.swift"]),
    visibility = ["//visibility:public"],
    deps = [":ArgumentParserToolInfo"],
)
swift_library(
    name = "ArgumentParserToolInfo",
    srcs = glob(["Sources/ArgumentParserToolInfo/**/*.swift"]),
    visibility = ["//visibility:public"],
)
""",
    sha256 = "f2c3a7f20e6dede610e7bd7e6cc9e352df54070769bc5b7f5d4bb2868e3c10ae",
    strip_prefix = "swift-argument-parser-1.2.0",
    url = "https://github.com/apple/swift-argument-parser/archive/1.2.0.tar.gz",
)
`
