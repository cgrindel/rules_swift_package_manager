package swift_test

import (
	"fmt"
	"testing"

	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestRepoRuleFromPin(t *testing.T) {
	miBasename := "module_index.json"
	remote := "https://github.com/apple/swift-argument-parser"
	version := "1.2.3"
	revision := "12345"
	p := &spreso.Pin{
		PkgRef: &spreso.PackageReference{
			Kind:     spreso.RemoteSourceControlPkgRefKind,
			Location: remote,
		},
		State: &spreso.VersionPinState{
			Version:  version,
			Revision: revision,
		},
	}
	modules := map[string]string{
		"ArgumentParser": "//:ArgumentParser",
	}
	actual, err := swift.RepoRuleFromPin(p, modules, miBasename)
	assert.NoError(t, err)

	expected := rule.NewRule(swift.SwiftPkgRuleKind, "apple_swift_argument_parser")
	expected.SetAttr("commit", revision)
	expected.SetAttr("remote", remote)
	expected.SetAttr("modules", modules)
	expected.SetAttr("module_index", fmt.Sprintf("@//:%s", miBasename))
	expected.AddComment("# version: 1.2.3")
	assert.Equal(t, expected, actual)
}
