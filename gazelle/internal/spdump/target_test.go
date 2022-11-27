package spdump_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
	"github.com/stretchr/testify/assert"
)

func TestTargetImports(t *testing.T) {
	target := spdump.Target{
		Name: "Foo",
		Type: spdump.LibraryTargetType,
		Dependencies: []spdump.TargetDependency{
			{
				Product: &spdump.ProductReference{
					ProductName:    "ArgumentParser",
					DependencyName: "swift-argument-parser",
				},
			},
			{
				ByName: &spdump.ByNameReference{TargetName: "MySwiftPackage"},
			},
		},
	}
	actual := target.Imports()
	assert.Equal(t, []string{"ArgumentParser", "MySwiftPackage"}, actual)
}
