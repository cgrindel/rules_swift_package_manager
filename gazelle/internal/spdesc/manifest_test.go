package spdesc_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spdesc"
	"github.com/stretchr/testify/assert"
)

func TestNewManifestFromJSON(t *testing.T) {
	expected := &spdesc.Manifest{
		Name:                "MySwiftPackage",
		ManifestDisplayName: "MySwiftPackage",
		Path:                "/Users/chuck/code/cgrindel/swift_bazel/gh008_incorporate_describe/examples/MySwiftPackage",
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
  "path" : "/Users/chuck/code/cgrindel/swift_bazel/gh008_incorporate_describe/examples/MySwiftPackage",
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
