"""Tests for `pkginfos` API"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")

def _get_test(ctx):
    env = unittest.begin(ctx)

    dump_manifest = json.decode(_dump_manifest_json)
    desc_manifest = json.decode(_desc_manifest_json)
    actual = pkginfos.new_from_parsed_json(
        dump_manifest = dump_manifest,
        desc_manifest = desc_manifest,
    )
    expected = pkginfos.new(
        name = "MySwiftPackage",
        path = "/Users/chuck/code/cgrindel/swift_bazel/gh009_update_repos_new/examples/pkg_manifest",
        tools_version = "5.7.0",
        platforms = [
            pkginfos.new_platform(name = "macos", version = "10.15"),
        ],
        dependencies = [
            pkginfos.new_dependency(
                identity = "swift-argument-parser",
                type = "sourceControl",
                url = "https://github.com/apple/swift-argument-parser",
                requirement = pkginfos.new_dependency_requirement(
                    ranges = [
                        pkginfos.new_version_range("1.2.0", "2.0.0"),
                    ],
                ),
            ),
        ],
        products = [
            pkginfos.new_product(
                name = "printstuff",
                targets = ["MySwiftPackage"],
                type = pkginfos.new_product_type(executable = True),
            ),
        ],
        targets = [
            pkginfos.new_target(
                name = "MySwiftPackage",
                type = "executable",
                c99name = "MySwiftPackage",
                module_type = "SwiftTarget",
                path = "Sources/MySwiftPackage",
                sources = [
                    "MySwiftPackage.swift",
                ],
                dependencies = [
                    pkginfos.new_target_dependency(
                        product = pkginfos.new_product_reference(
                            product_name = "ArgumentParser",
                            dep_identity = "swift-argument-parser",
                        ),
                    ),
                ],
                clang_settings = pkginfos.new_clang_settings(
                    defines = ["__APPLE_USE_RFC_3542"],
                ),
            ),
            pkginfos.new_target(
                name = "MySwiftPackageTests",
                type = "test",
                c99name = "MySwiftPackageTests",
                module_type = "SwiftTarget",
                path = "Tests/MySwiftPackageTests",
                sources = [
                    "MySwiftPackageTests.swift",
                ],
                dependencies = [
                    pkginfos.new_target_dependency(
                        by_name = pkginfos.new_by_name_reference(
                            name = "MySwiftPackage",
                        ),
                    ),
                ],
            ),
        ],
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

get_test = unittest.make(_get_test)

def pkginfos_test_suite():
    return unittest.suite(
        "pkginfos_tests",
        get_test,
    )

_dump_manifest_json = """
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
      "/Users/chuck/code/cgrindel/swift_bazel/gh009_update_repos_new/examples/pkg_manifest"
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
          {
            "kind" : {
              "define" : {
                "_0" : "__APPLE_USE_RFC_3542"
              }
            },
            "tool" : "c"
          }
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
"""

_desc_manifest_json = """
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
  "path" : "/Users/chuck/code/cgrindel/swift_bazel/gh009_update_repos_new/examples/pkg_manifest",
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
"""
