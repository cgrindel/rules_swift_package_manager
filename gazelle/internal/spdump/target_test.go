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
				ByName: &spdump.ByNameReference{Name: "MySwiftPackage"},
			},
		},
	}
	actual := target.Imports()
	assert.Equal(t, []string{"ArgumentParser", "MySwiftPackage"}, actual)
}

func TestTargetsByName(t *testing.T) {
	foo := spdump.Target{Name: "Foo"}
	bar := spdump.Target{Name: "Bar"}
	targets := spdump.Targets{foo, bar}

	actual := targets.FindByName("Foo")
	assert.Equal(t, &foo, actual)

	actual = targets.FindByName("Bar")
	assert.Equal(t, &bar, actual)

	actual = targets.FindByName("DoesNotExist")
	assert.Nil(t, actual)
}
