package spdump_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdump"
	"github.com/stretchr/testify/assert"
)

func TestNewManifestFromJSON(t *testing.T) {
	expected := &spdump.Manifest{
		Name: "MySwiftPackage",
		Dependencies: []spdump.Dependency{
			{
				SourceControl: &spdump.SourceControl{
					Identity: "swift-argument-parser",
					Location: &spdump.SourceControlLocation{
						Remote: &spdump.RemoteLocation{
							URL: "https://github.com/apple/swift-argument-parser",
						},
					},
					Requirement: &spdump.DependencyRequirement{
						Ranges: []*spdump.VersionRange{
							&spdump.VersionRange{LowerBound: "1.2.0", UpperBound: "2.0.0"},
						},
					},
				},
			},
		},
		Platforms: []spdump.Platform{
			{Name: "macos", Version: "10.15"},
		},
		Products: []spdump.Product{
			{
				Name:    "printstuff",
				Targets: []string{"MySwiftPackage"},
				Type:    spdump.ExecutableProductType,
			},
		},
		Targets: []spdump.Target{
			{
				Name: "MySwiftPackage",
				Type: spdump.ExecutableTargetType,
				Dependencies: []spdump.TargetDependency{
					{
						Product: &spdump.ProductReference{
							ProductName:    "ArgumentParser",
							DependencyName: "swift-argument-parser",
						},
					},
				},
			},
			{
				Name: "MySwiftPackageTests",
				Type: spdump.TestTargetType,
				Dependencies: []spdump.TargetDependency{
					{
						ByName: &spdump.ByNameReference{TargetName: "MySwiftPackage"},
					},
				},
			},
		},
	}
	manifest, err := spdump.NewManifestFromJSON([]byte(swiftPackageJSONStr))
	assert.NoError(t, err)
	assert.Equal(t, expected, manifest)
}

func TestManifestProductReferences(t *testing.T) {
	m := spdump.Manifest{
		Targets: []spdump.Target{
			{
				Dependencies: []spdump.TargetDependency{
					{Product: &spdump.ProductReference{ProductName: "Foo", DependencyName: "repoA"}},
					{Product: &spdump.ProductReference{ProductName: "Bar", DependencyName: "repoA"}},
					{Product: &spdump.ProductReference{ProductName: "Chicken", DependencyName: "repoB"}},
				},
			},
			{
				Dependencies: []spdump.TargetDependency{
					{Product: &spdump.ProductReference{ProductName: "Foo", DependencyName: "repoA"}},
					{Product: &spdump.ProductReference{ProductName: "Smidgen", DependencyName: "repoB"}},
				},
			},
		},
	}

	actual := m.ProductReferences()
	expected := []*spdump.ProductReference{
		&spdump.ProductReference{ProductName: "Bar", DependencyName: "repoA"},
		&spdump.ProductReference{ProductName: "Foo", DependencyName: "repoA"},
		&spdump.ProductReference{ProductName: "Chicken", DependencyName: "repoB"},
		&spdump.ProductReference{ProductName: "Smidgen", DependencyName: "repoB"},
	}
	assert.Equal(t, expected, actual)
}

const swiftPackageJSONStr = `
{
  "cLanguageStandard" : null,
  "cxxLanguageStandard" : null,
  "dependencies" : [
    {
      "sourceControl" : [
        {
          "identity" : "swift-argument-parser",
          "location" : {
            "remote" : [
              "https://github.com/apple/swift-argument-parser"
            ]
          },
          "productFilter" : null,
          "requirement" : {
            "range" : [
              {
                "lowerBound" : "1.2.0",
                "upperBound" : "2.0.0"
              }
            ]
          }
        }
      ]
    }
  ],
  "name" : "MySwiftPackage",
  "packageKind" : {
    "root" : [
      "/Users/chuck/code/cgrindel/swift_bazel/gh008_simple_package_gen/examples/MySwiftPackage"
    ]
  },
  "pkgConfig" : null,
  "platforms" : [
    {
      "options" : [

      ],
      "platformName" : "macos",
      "version" : "10.15"
    }
  ],
  "products" : [
    {
      "name" : "printstuff",
      "settings" : [

      ],
      "targets" : [
        "MySwiftPackage"
      ],
      "type" : {
        "executable" : null
      }
    }
  ],
  "providers" : null,
  "swiftLanguageVersions" : null,
  "targets" : [
    {
      "dependencies" : [
        {
          "product" : [
            "ArgumentParser",
            "swift-argument-parser",
            null,
            null
          ]
        }
      ],
      "exclude" : [

      ],
      "name" : "MySwiftPackage",
      "resources" : [

      ],
      "settings" : [

      ],
      "type" : "executable"
    },
    {
      "dependencies" : [
        {
          "byName" : [
            "MySwiftPackage",
            null
          ]
        }
      ],
      "exclude" : [

      ],
      "name" : "MySwiftPackageTests",
      "resources" : [

      ],
      "settings" : [

      ],
      "type" : "test"
    }
  ],
  "toolsVersion" : {
    "_version" : "5.7.0"
  }
}
`
