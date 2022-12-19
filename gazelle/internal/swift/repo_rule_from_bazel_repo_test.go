package swift_test

import (
	"testing"
)

func TestRepoRuleFromBazelRepo(t *testing.T) {
	t.Error("IMPLEMENT ME!")
	// miBasename := "module_index.json"
	// remote := "https://github.com/apple/swift-argument-parser"
	// version := "1.2.3"
	// revision := "12345"
	// p := &spreso.Pin{
	// 	PkgRef: &spreso.PackageReference{
	// 		Kind:     spreso.RemoteSourceControlPkgRefKind,
	// 		Location: remote,
	// 	},
	// 	State: &spreso.VersionPinState{
	// 		Version:  version,
	// 		Revision: revision,
	// 	},
	// }
	// actual, err := swift.RepoRuleFromPin(p, miBasename)
	// assert.NoError(t, err)

	// expected := rule.NewRule(swift.SwiftPkgRuleKind, "apple_swift_argument_parser")
	// expected.SetAttr("commit", revision)
	// expected.SetAttr("remote", remote)
	// expected.SetAttr("module_index", fmt.Sprintf("@//:%s", miBasename))
	// expected.AddComment("# version: 1.2.3")
	// assert.Equal(t, expected, actual)
}
