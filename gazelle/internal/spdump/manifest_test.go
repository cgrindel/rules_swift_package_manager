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
			{
				FileSystem: &spdump.FileSystem{
					Identity: "my-local-package",
					Path:     "/path/to/my-local-package",
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
				Settings: []spdump.TargetSetting{},
			},
			{
				Name: "MySwiftPackageTests",
				Type: spdump.TestTargetType,
				Dependencies: []spdump.TargetDependency{
					{
						ByName: &spdump.ByNameReference{Name: "MySwiftPackage"},
					},
				},
				Settings: []spdump.TargetSetting{},
			},
		},
	}
	manifest, err := spdump.NewManifestFromJSON([]byte(swiftPackageJSONStr))
	assert.NoError(t, err)
	assert.Equal(t, expected, manifest)
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
    },
	{
	  "fileSystem": [
	    {
		  "identity": "my-local-package",
		  "path": "/path/to/my-local-package",
		  "productFilter": null
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
