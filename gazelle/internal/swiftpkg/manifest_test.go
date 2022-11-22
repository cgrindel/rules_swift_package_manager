package swiftpkg_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestNewManifestFromJSON(t *testing.T) {
	expected := &swiftpkg.Manifest{
		Name: "MySwiftPackage",
		Dependencies: []swiftpkg.Dependency{
			{
				Name: "swift-argument-parser",
				URL:  "https://github.com/apple/swift-argument-parser",
				Requirement: swiftpkg.DependencyRequirement{
					Range: []swiftpkg.VersionRange{
						{LowerBound: "1.2.0", UpperBound: "2.0.0"},
					},
				},
			},
		},
		Platforms: []swiftpkg.Platform{
			{Name: "macos", Version: "10.15"},
		},
		Products: []swiftpkg.Product{
			{
				Name:    "printstuff",
				Targets: []string{"MySwiftPackage"},
				Type:    swiftpkg.ExecutableProductType,
			},
		},
		Targets: []swiftpkg.Target{
			{
				Name: "MySwiftPackage",
				Type: swiftpkg.ExecutableTargetType,
				Dependencies: []swiftpkg.TargetDependency{
					{
						Product: &swiftpkg.ProductReference{
							ProductName:    "ArgumentParser",
							DependencyName: "swift-argument-parser",
						},
					},
				},
			},
			{
				Name: "MySwiftPackageTests",
				Type: swiftpkg.TestTargetType,
				Dependencies: []swiftpkg.TargetDependency{
					{
						ByName: &swiftpkg.ByNameReference{TargetName: "MySwiftPackage"},
					},
				},
			},
		},
	}
	manifest, err := swiftpkg.NewManifestFromJSON([]byte(swiftPackageJSONStr))
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
