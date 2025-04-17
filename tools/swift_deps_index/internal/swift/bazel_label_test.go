package swift_test

import (
	"testing"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swift"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestBazelLabelFromTarget(t *testing.T) {
	tests := []struct {
		msg        string
		repoName   string
		targetName string
		targetPath string
		exp        string
	}{
		{
			msg:        "regular path",
			repoName:   "example_cool_repo",
			targetName: "Foo",
			targetPath: "Sources/Foo",
			exp:        "@example_cool_repo//:Foo.rspm",
		},
		{
			msg:        "simple path",
			repoName:   "example_cool_repo",
			targetName: "simple_path",
			targetPath: "simple_path",
			exp:        "@example_cool_repo//:simple_path.rspm",
		},
	}
	for _, tt := range tests {
		target := &swiftpkg.Target{
			Name: tt.targetName,
			Path: tt.targetPath,
		}
		actual := swift.BazelLabelFromTarget(tt.repoName, target)
		expected, err := label.Parse(tt.exp)
		assert.NoError(t, err)
		assert.Equal(t, &expected, actual, tt.msg)
	}
}

func TestModulemapBazelLabelFromTargetLabel(t *testing.T) {
	targetLabel := label.New("example_cool_repo", "bzlpkg", "foo")
	actual := swift.ModulemapBazelLabelFromTargetLabel(&targetLabel)
	expected := label.New("example_cool_repo", "bzlpkg", "foo_modulemap")
	assert.Equal(t, &expected, actual)
}
