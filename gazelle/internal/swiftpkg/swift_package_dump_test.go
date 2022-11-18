package swiftpkg_test

import (
	"log"
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestNewDumpFromJSON(t *testing.T) {
	expected := &swiftpkg.Dump{
		Name: "MySwiftPackage",
		Dependencies: []swiftpkg.DumpDependency{
			{Name: "swift-argument-parser", URL: "https://github.com/apple/swift-argument-parser"},
		},
	}
	dump, err := swiftpkg.NewDumpFromJSON([]byte(swiftPackageJSONStr))
	assert.NoError(t, err)
	assert.Equal(t, expected, dump)

	// DEBUG BEGIN
	log.Printf("*** CHUCK:  dump: %+#v", dump)
	log.Printf("*** CHUCK dump.Dependencies: ")
	for idx, item := range dump.Dependencies {
		log.Printf("*** CHUCK %d: %+#v", idx, item)
	}
	// assert.Fail(t, "STOP")
	// DEBUG END
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
