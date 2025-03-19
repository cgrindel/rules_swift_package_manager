package spdesc_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/spdesc"
	"github.com/stretchr/testify/assert"
)

func TestNewManifestFromJSON(t *testing.T) {
	expected := &spdesc.Manifest{
		Name:                "MySwiftPackage",
		ManifestDisplayName: "MySwiftPackage",
		Path:                "/Users/chuck/code/cgrindel/rules_swift_package_manager/gh008_incorporate_describe/examples/MySwiftPackage",
		ToolsVersion:        "5.7",
		Dependencies: []spdesc.Dependency{
			{
				Identity: "swift-argument-parser",
				Type:     "sourceControl",
				URL:      "https://github.com/apple/swift-argument-parser",
				Requirement: spdesc.DependencyRequirement{
					Range: []spdesc.VersionRange{
						{LowerBound: "1.2.0", UpperBound: "2.0.0"},
					},
				},
			},
		},
		Platforms: []spdesc.Platform{
			{Name: "macos", Version: "10.15"},
		},
		Products: []spdesc.Product{
			{
				Name:    "printstuff",
				Targets: []string{"MySwiftPackage"},
				Type:    spdesc.ExecutableProductType,
			},
		},
		Targets: []spdesc.Target{
			{
				Name:       "MySwiftPackageTests",
				C99name:    "MySwiftPackageTests",
				ModuleType: "SwiftTarget",
				Path:       "Tests/MySwiftPackageTests",
				Sources: []string{
					"MySwiftPackageTests.swift",
				},
				TargetDependencies: []string{
					"MySwiftPackage",
				},
				Type: "test",
			},
			{
				Name:       "MySwiftPackage",
				C99name:    "MySwiftPackage",
				Type:       "executable",
				ModuleType: "SwiftTarget",
				Path:       "Sources/MySwiftPackage",
				Sources: []string{
					"MySwiftPackage.swift",
				},
				ProductDependencies: []string{
					"ArgumentParser",
				},
				ProductMemberships: []string{
					"printstuff",
				},
			},
		},
	}
	manifest, err := spdesc.NewManifestFromJSON([]byte(swiftPackageJSONStr))
	assert.NoError(t, err)
	assert.Equal(t, expected, manifest)
}

func TestTargetsFromName(t *testing.T) {
	manifest, err := spdesc.NewManifestFromJSON([]byte(swiftPackageJSONStr))
	assert.NoError(t, err)

	actual := manifest.Targets.FindByName("MySwiftPackage")
	assert.NotNil(t, actual)

	actual = manifest.Targets.FindByName("DoesNotExist")
	assert.Nil(t, actual)
}

func TestTargetsFromPath(t *testing.T) {
	foo := spdesc.Target{Name: "Foo", Path: "Sources/Foo"}
	bar := spdesc.Target{Name: "Bar", Path: "Sources/Bar"}
	targets := spdesc.Targets{foo, bar}

	actual := targets.FindByPath("Sources/Foo")
	assert.Equal(t, &foo, actual)

	actual = targets.FindByPath("Sources/Bar")
	assert.Equal(t, &bar, actual)

	actual = targets.FindByPath("Sources/Another")
	assert.Nil(t, actual)
}

func TestTargetSourcesWithPath(t *testing.T) {
	target := spdesc.Target{
		Sources: []string{
			"Foo.swift",
			"Bar.swift",
		},
	}

	t.Run("path is empty string", func(t *testing.T) {
		target.Path = ""
		actual := target.SourcesWithPath()
		assert.Equal(t, target.Sources, actual)
	})
	t.Run("path is not empty string", func(t *testing.T) {
		target.Path = "Sources/Chicken"
		actual := target.SourcesWithPath()
		expected := []string{
			"Sources/Chicken/Foo.swift",
			"Sources/Chicken/Bar.swift",
		}
		assert.Equal(t, expected, actual)
	})
}

const swiftPackageJSONStr = `
{
  "dependencies" : [
    {
      "identity" : "swift-argument-parser",
      "requirement" : {
        "range" : [
          {
            "lower_bound" : "1.2.0",
            "upper_bound" : "2.0.0"
          }
        ]
      },
      "type" : "sourceControl",
      "url" : "https://github.com/apple/swift-argument-parser"
    }
  ],
  "manifest_display_name" : "MySwiftPackage",
  "name" : "MySwiftPackage",
  "path" : "/Users/chuck/code/cgrindel/rules_swift_package_manager/gh008_incorporate_describe/examples/MySwiftPackage",
  "platforms" : [
    {
      "name" : "macos",
      "version" : "10.15"
    }
  ],
  "products" : [
    {
      "name" : "printstuff",
      "targets" : [
        "MySwiftPackage"
      ],
      "type" : {
        "executable" : null
      }
    }
  ],
  "targets" : [
    {
      "c99name" : "MySwiftPackageTests",
      "module_type" : "SwiftTarget",
      "name" : "MySwiftPackageTests",
      "path" : "Tests/MySwiftPackageTests",
      "sources" : [
        "MySwiftPackageTests.swift"
      ],
      "target_dependencies" : [
        "MySwiftPackage"
      ],
      "type" : "test"
    },
    {
      "c99name" : "MySwiftPackage",
      "module_type" : "SwiftTarget",
      "name" : "MySwiftPackage",
      "path" : "Sources/MySwiftPackage",
      "product_dependencies" : [
        "ArgumentParser"
      ],
      "product_memberships" : [
        "printstuff"
      ],
      "sources" : [
        "MySwiftPackage.swift"
      ],
      "type" : "executable"
    }
  ],
  "tools_version" : "5.7"
}
`
