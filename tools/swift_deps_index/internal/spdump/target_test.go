package spdump_test

import (
	"encoding/json"
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spdump"
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

func TestTargetSettingUnmarshalJSON(t *testing.T) {
	expected := []spdump.TargetSetting{
		{
			Tool:    spdump.ClangToolType,
			Kind:    spdump.DefineTargetSettingKind,
			Defines: []string{"__APPLE_USE_RFC_3542"},
		},
	}

	var settings []spdump.TargetSetting
	err := json.Unmarshal([]byte(targetSettingsJSON), &settings)
	assert.NoError(t, err)
	assert.Equal(t, expected, settings)
}

const targetSettingsJSON = `
[
  {
    "kind" : {
      "define" : {
        "_0" : "__APPLE_USE_RFC_3542"
      }
    },
    "tool" : "c"
  }
]
`
