package swift_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spreso"
	"github.com/cgrindel/swift_bazel/gazelle/internal/swift"
	"github.com/stretchr/testify/assert"
)

func TestRepoRuleFromPin(t *testing.T) {
	remote := "https://github.com/apple/swift-argument-parser"
	version := "1.2.3"
	revision := "12345"
	p := &spreso.Pin{
		PkgRef: &spreso.PackageReference{
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
	_, err := swift.RepoRuleFromPin(p, modules)
	assert.NoError(t, err)

	t.Error("IMPLEMENT ME!")

	// expected := rule.NewRule(swift.SwiftPkgRuleKind, "apple_swift_argument_parser")
	// expected.SetAttr("commit", revision)
	// expected.SetAttr("remote", remote)
	// expected.SetAttr("modules", modules)
	// expected.AddComment("# version: 1.2.3")
	// assert.Equal(t, expected, actual)

	// assert.Equal(t, swift.SwiftPkgRuleKind, actual.Kind())
	// expectedName, err := swift.RepoNameFromPin(p)
	// assert.NoError(t, err)
	// assert.Equal(t, expectedName, actual.Name())
	// assert.Equal(t, remote, actual.AttrString("remote"))
	// assert.Equal(t, revision, actual.AttrString("commit"))
	// modulesExpr := actual.Attr("modules")
	// if listExpr, ok := modulesExpr.(*build.ListExpr); ok {
	// 	assert.Len(t, listExpr.List, 1)
	// 	if strExpr, ok := listExpr.List[0].(*build.StringExpr); ok {
	// 		assert.Equal(t, "ArgumentParser", strExpr.Value)
	// 	} else {
	// 		assert.Fail(t, "Expected to be a StringExpr")
	// 	}
	// } else {
	// 	assert.Fail(t, "Expected to be a ListExpr")
	// }
	// // assert.Equal(t, modules, actual.Attr("modules"))
	// assert.Len(t, actual.Comments(), 1)
	// assert.Contains(t, actual.Comments()[0], "# version: 1.2.3")
}
