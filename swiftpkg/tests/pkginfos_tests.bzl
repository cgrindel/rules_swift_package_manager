"""Tests for `pkginfos` API"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "make_bazel_labels", "make_stub_workspace_name_resolvers")
load("//swiftpkg/internal:pkginfo_targets.bzl", "make_pkginfo_targets")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load(":testutils.bzl", "testutils")

workspace_name_resolovers = make_stub_workspace_name_resolvers(
    repo_name = "",
)
bazel_labels = make_bazel_labels(workspace_name_resolovers)
pkginfo_targets = make_pkginfo_targets(bazel_labels)

# MARK: - Tests

def _new_from_parsed_json_for_swift_targets_test(ctx):
    env = unittest.begin(ctx)

    repo_name = "swiftpkg_mypackage"
    dump_manifest = json.decode(_swift_arg_parser_dump_json)
    desc_manifest = json.decode(_swift_arg_parser_desc_json)
    actual = pkginfos.new_from_parsed_json(
        repository_ctx = testutils.new_stub_repository_ctx(repo_name),
        dump_manifest = dump_manifest,
        desc_manifest = desc_manifest,
        collect_src_info = False,
    )
    expected = pkginfos.new(
        name = "MySwiftPackage",
        path = "/Users/chuck/code/cgrindel/rules_swift_package_manager/gh009_update_repos_new/examples/pkg_manifest",
        tools_version = "5.7.0",
        platforms = [
            pkginfos.new_platform(name = "macos", version = "10.15"),
        ],
        dependencies = [
            pkginfos.new_dependency(
                identity = "swift-argument-parser",
                name = "SwiftArgumentParser",
                source_control = pkginfos.new_source_control(
                    pin = pkginfos.new_pin(
                        identity = "swift-argument-parser",
                        kind = "remoteSourceControl",
                        location = "https://github.com/apple/swift-argument-parser",
                        state = pkginfos.new_pin_state(
                            revision = "6c89474e62719ddcc1e9614989fff2f68208fe10",
                            version = "1.0.0",
                        ),
                    ),
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
                            dep_name = "SwiftArgumentParser",
                        ),
                    ),
                ],
                repo_name = repo_name,
                clang_settings = pkginfos.new_clang_settings([
                    pkginfos.new_build_setting(
                        kind = "headerSearchPath",
                        values = ["../.."],
                    ),
                ]),
                swift_settings = pkginfos.new_swift_settings([
                    pkginfos.new_build_setting(
                        kind = "define",
                        values = ["COOL_SWIFT_DEFINE"],
                    ),
                ]),
                linker_settings = pkginfos.new_linker_settings([
                    pkginfos.new_build_setting(
                        kind = "linkedFramework",
                        values = ["UIKit"],
                        condition = pkginfos.new_build_setting_condition(
                            platforms = ["ios", "tvos"],
                        ),
                    ),
                    pkginfos.new_build_setting(
                        kind = "linkedFramework",
                        values = ["AppKit"],
                        condition = pkginfos.new_build_setting_condition(
                            platforms = ["macos"],
                        ),
                    ),
                ]),
                product_memberships = ["printstuff"],
                resources = [
                    pkginfos.new_resource(
                        path = "Sources/MySwiftPackage/Resources/chicken.json",
                        rule = pkginfos.new_resource_rule(
                            process = pkginfos.new_resource_rule_process(),
                        ),
                    ),
                ],
                swift_src_info = pkginfos.new_swift_src_info(),
            ),
        ],
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

new_from_parsed_json_for_swift_targets_test = unittest.make(_new_from_parsed_json_for_swift_targets_test)

def _new_from_parsed_json_for_clang_targets_test(ctx):
    env = unittest.begin(ctx)

    repo_name = "swiftpkg_libbar"
    dump_manifest = json.decode(_clang_dump_json)
    desc_manifest = json.decode(_clang_desc_json)
    actual = pkginfos.new_from_parsed_json(
        repository_ctx = testutils.new_stub_repository_ctx(repo_name),
        dump_manifest = dump_manifest,
        desc_manifest = desc_manifest,
        collect_src_info = False,
    )

    # The interesting features are in the libbar target.
    libbar_target = actual.targets[0]
    expected = pkginfos.new_target(
        name = "libbar",
        type = "regular",
        c99name = "libbar",
        module_type = "ClangTarget",
        path = ".",
        sources = [
            "libbar/sharpyuv/sharpyuv.c",
            "libbar/sharpyuv/sharpyuv_csp.c",
            "libbar/sharpyuv/sharpyuv_dsp.c",
            "libbar/sharpyuv/sharpyuv_gamma.c",
            "libbar/sharpyuv/sharpyuv_neon.c",
            "libbar/sharpyuv/sharpyuv_sse2.c",
        ],
        dependencies = [],
        label = pkginfo_targets.bazel_label_from_parts(
            target_name = "libbar",
            repo_name = "",
        ),
        source_paths = [
            "libbar/src",
            "libbar/sharpyuv",
        ],
        clang_settings = pkginfos.new_clang_settings([
            pkginfos.new_build_setting(
                kind = "define",
                values = ["__APPLE_USE_RFC_3542"],
            ),
            pkginfos.new_build_setting(
                kind = "headerSearchPath",
                values = ["libbar"],
            ),
        ]),
        linker_settings = pkginfos.new_linker_settings([
            pkginfos.new_build_setting(
                kind = "linkedLibrary",
                values = ["foo"],
            ),
        ]),
        public_hdrs_path = "include",
    )
    asserts.equals(env, expected, libbar_target)

    return unittest.end(env)

new_from_parsed_json_for_clang_targets_test = unittest.make(_new_from_parsed_json_for_clang_targets_test)

def _target_dependency_from_json_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "byName, no condition",
            json = """\
{
  "byName" : [
    "MyLibrary",
    null
  ]
}
""",
            exp = pkginfos.new_target_dependency(
                by_name = pkginfos.new_by_name_reference(
                    name = "MyLibrary",
                ),
            ),
        ),
        struct(
            msg = "byName, with condition",
            json = """\
{
  "byName" : [
    "MyLibrary",
    {
      "platformNames" : [
        "ios"
      ]
    }
  ]
}
""",
            exp = pkginfos.new_target_dependency(
                by_name = pkginfos.new_by_name_reference(
                    name = "MyLibrary",
                    condition = pkginfos.new_target_dependency_condition(
                        platforms = ["ios"],
                    ),
                ),
            ),
        ),
        struct(
            msg = "product, no condition",
            json = """\
{
  "product" : [
    "Logging",
    "swift-log",
    null,
    null
  ]
}
""",
            exp = pkginfos.new_target_dependency(
                product = pkginfos.new_product_reference(
                    product_name = "Logging",
                    dep_name = "swift-log",
                ),
            ),
        ),
        struct(
            msg = "product, with condition",
            json = """\
{
  "product" : [
    "Logging",
    "swift-log",
    null,
    {
      "platformNames" : [
        "ios"
      ]
    }
  ]
}
""",
            exp = pkginfos.new_target_dependency(
                product = pkginfos.new_product_reference(
                    product_name = "Logging",
                    dep_name = "swift-log",
                    condition = pkginfos.new_target_dependency_condition(
                        platforms = ["ios"],
                    ),
                ),
            ),
        ),
        struct(
            msg = "target, no condition",
            json = """\
{
  "target" : [
    "MyLibrary",
    null
  ]
}
""",
            exp = pkginfos.new_target_dependency(
                target = pkginfos.new_target_reference(
                    target_name = "MyLibrary",
                ),
            ),
        ),
        struct(
            msg = "target, with condition",
            json = """\
{
  "target" : [
    "MyLibrary",
    {
      "platformNames" : [
        "ios"
      ]
    }
  ]
}
""",
            exp = pkginfos.new_target_dependency(
                target = pkginfos.new_target_reference(
                    target_name = "MyLibrary",
                    condition = pkginfos.new_target_dependency_condition(
                        platforms = ["ios"],
                    ),
                ),
            ),
        ),
    ]
    for t in tests:
        dump_map = json.decode(t.json)
        actual = pkginfos.new_target_dependency_from_dump_json_map(dump_map)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

target_dependency_from_json_test = unittest.make(_target_dependency_from_json_test)

def pkginfos_test_suite():
    return unittest.suite(
        "pkginfos_tests",
        new_from_parsed_json_for_swift_targets_test,
        new_from_parsed_json_for_clang_targets_test,
        target_dependency_from_json_test,
    )

_swift_arg_parser_dump_json = """
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
          "nameForTargetDependencyResolutionOnly": "SwiftArgumentParser",
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
      "/Users/chuck/code/cgrindel/rules_swift_package_manager/gh009_update_repos_new/examples/pkg_manifest"
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
            "SwiftArgumentParser",
            null,
            null
          ]
        }
      ],
      "exclude" : [

      ],
      "name" : "MySwiftPackage",
      "resources": [
        {
          "path" : "Resources/chicken.json",
          "rule" : { "process" : {} }
        }
      ],
      "settings" : [
          {
            "kind" : {
              "define" : {
                "_0" : "COOL_SWIFT_DEFINE"
              }
            },
            "tool" : "swift"
          },
          {
            "kind" : {
              "headerSearchPath" : {
                "_0" : "../.."
              }
            },
            "tool" : "c"
          },
          {
            "condition" : {
              "platformNames" : [
                "ios",
                "tvos"
              ]
            },
            "kind" : {
              "linkedFramework" : {
                "_0" : "UIKit"
              }
            },
            "tool" : "linker"
          },
          {
            "condition" : {
              "platformNames" : [
                "macos"
              ]
            },
            "kind" : {
              "linkedFramework" : {
                "_0" : "AppKit"
              }
            },
            "tool" : "linker"
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

_swift_arg_parser_desc_json = """
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
  "path" : "/Users/chuck/code/cgrindel/rules_swift_package_manager/gh009_update_repos_new/examples/pkg_manifest",
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
      "resources": [
        {
          "path" : "/Users/chuck/code/cgrindel/rules_swift_package_manager/gh009_update_repos_new/examples/pkg_manifest/Sources/MySwiftPackage/Resources/chicken.json",
          "rule" : { "process" : {} }
        }
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

_clang_dump_json = """
{
  "cLanguageStandard" : null,
  "cxxLanguageStandard" : null,
  "dependencies" : [

  ],
  "name" : "libbar",
  "packageKind" : {
    "root" : [
      "/path/to/libbar"
    ]
  },
  "pkgConfig" : null,
  "platforms" : [
    {
      "options" : [

      ],
      "platformName" : "macos",
      "version" : "10.10"
    },
    {
      "options" : [

      ],
      "platformName" : "ios",
      "version" : "9.0"
    },
    {
      "options" : [

      ],
      "platformName" : "tvos",
      "version" : "9.0"
    },
    {
      "options" : [

      ],
      "platformName" : "watchos",
      "version" : "2.0"
    }
  ],
  "products" : [
    {
      "name" : "libbar",
      "settings" : [

      ],
      "targets" : [
        "libbar"
      ],
      "type" : {
        "library" : [
          "automatic"
        ]
      }
    }
  ],
  "providers" : null,
  "swiftLanguageVersions" : null,
  "targets" : [
    {
      "dependencies" : [

      ],
      "exclude" : [

      ],
      "name" : "libbar",
      "path" : ".",
      "publicHeadersPath" : "include",
      "resources" : [

      ],
      "settings" : [
        {
          "kind" : {
            "headerSearchPath" : {
              "_0" : "libbar"
            }
          },
          "tool" : "c"
        },
        {
          "kind" : {
            "linkedLibrary" : {
              "_0" : "foo"
            }
          },
          "tool" : "linker"
        },
        {
          "kind" : {
            "define" : {
              "_0" : "__APPLE_USE_RFC_3542"
            }
          },
          "tool" : "c"
        }
      ],
      "sources" : [
        "libbar/src",
        "libbar/sharpyuv"
      ],
      "type" : "regular"
    }
  ],
  "toolsVersion" : {
    "_version" : "5.5.0"
  }
}
"""

_clang_desc_json = """
{
  "dependencies" : [

  ],
  "manifest_display_name" : "libbar",
  "name" : "libbar",
  "path" : "/path/to/libbar",
  "platforms" : [
    {
      "name" : "macos",
      "version" : "10.10"
    },
    {
      "name" : "ios",
      "version" : "9.0"
    },
    {
      "name" : "tvos",
      "version" : "9.0"
    },
    {
      "name" : "watchos",
      "version" : "2.0"
    }
  ],
  "products" : [
    {
      "name" : "libbar",
      "targets" : [
        "libbar"
      ],
      "type" : {
        "library" : [
          "automatic"
        ]
      }
    }
  ],
  "targets" : [
    {
      "c99name" : "libbar",
      "module_type" : "ClangTarget",
      "name" : "libbar",
      "path" : ".",
      "product_memberships" : [
        "libbar"
      ],
      "sources" : [
        "libbar/sharpyuv/sharpyuv.c",
        "libbar/sharpyuv/sharpyuv_csp.c",
        "libbar/sharpyuv/sharpyuv_dsp.c",
        "libbar/sharpyuv/sharpyuv_gamma.c",
        "libbar/sharpyuv/sharpyuv_neon.c",
        "libbar/sharpyuv/sharpyuv_sse2.c"
      ],
      "type" : "library"
    }
  ],
  "tools_version" : "5.5"
}
"""
