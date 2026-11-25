"""Manifest fixture text for the `MyPkg` slice tests.

`DUMP_JSON` and `DESC_JSON` are `MyPkg`, the root package.
"""

DUMP_JSON = """\
{
  "cLanguageStandard" : null,
  "cxxLanguageStandard" : null,
  "dependencies" : [
    {
      "fileSystem" : [
        {
          "identity" : "local_pkg",
          "path" : "../local_pkg",
          "productFilter" : null,
          "traits" : [
            {
              "name" : "default"
            }
          ]
        }
      ]
    }
  ],
  "name" : "MyPkg",
  "packageKind" : {
    "root" : [
      "./"
    ]
  },
  "pkgConfig" : null,
  "platforms" : [
    {
      "options" : [],
      "platformName" : "macos",
      "version" : "13.0"
    }
  ],
  "products" : [
    {
      "name" : "MyLib",
      "settings" : [],
      "targets" : [
        "MyLib"
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
        {
          "product" : [
            "LocalLib",
            "local_pkg",
            null,
            null
          ]
        }
      ],
      "exclude" : [],
      "name" : "MyLib",
      "packageAccess" : true,
      "resources" : [],
      "settings" : [],
      "type" : "regular"
    }
  ],
  "toolsVersion" : {
    "_version" : "5.9.0"
  },
  "traits" : []
}
"""

DESC_JSON = """\
{
  "dependencies" : [
    {
      "identity" : "local_pkg",
      "path" : "../local_pkg",
      "type" : "fileSystem"
    }
  ],
  "manifest_display_name" : "MyPkg",
  "name" : "MyPkg",
  "path" : "./",
  "platforms" : [
    {
      "name" : "macos",
      "version" : "13.0"
    }
  ],
  "products" : [
    {
      "name" : "MyLib",
      "targets" : [
        "MyLib"
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
      "c99name" : "MyLib",
      "module_type" : "SwiftTarget",
      "name" : "MyLib",
      "path" : "Sources/MyLib",
      "product_dependencies" : [
        "LocalLib"
      ],
      "product_memberships" : [
        "MyLib"
      ],
      "sources" : [
        "MyLib.swift"
      ],
      "type" : "library"
    }
  ],
  "tools_version" : "5.9"
}
"""

# A `Package.resolved` with one remote pin. `MyPkg` does not depend on it
# directly, so it reaches the repo set only through the pins.
RESOLVED_JSON = """\
{
  "pins" : [
    {
      "identity" : "swift-log",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/apple/swift-log",
      "state" : {
        "revision" : "96a2f8a0fa41e9e09af4585e2724c4e825410b91",
        "version" : "1.6.2"
      }
    }
  ],
  "version" : 2
}
"""

# `local_pkg`, which `MyPkg` reaches by `../local_pkg`. It depends on
# `leaf_pkg` by `../leaf_pkg`, so `leaf_pkg` is a transitive local package.
LOCAL_PKG_DUMP_JSON = """\
{
  "cLanguageStandard" : null,
  "cxxLanguageStandard" : null,
  "dependencies" : [
    {
      "fileSystem" : [
        {
          "identity" : "leaf_pkg",
          "path" : "../leaf_pkg",
          "productFilter" : null
        }
      ]
    }
  ],
  "name" : "local_pkg",
  "platforms" : [],
  "products" : [],
  "swiftLanguageVersions" : null,
  "targets" : [],
  "toolsVersion" : {
    "_version" : "5.9.0"
  }
}
"""

LOCAL_PKG_DESC_JSON = """\
{
  "dependencies" : [
    {
      "identity" : "leaf_pkg",
      "path" : "../leaf_pkg",
      "type" : "fileSystem"
    }
  ],
  "name" : "local_pkg",
  "path" : "./",
  "targets" : []
}
"""

LEAF_PKG_DUMP_JSON = """\
{
  "cLanguageStandard" : null,
  "cxxLanguageStandard" : null,
  "dependencies" : [],
  "name" : "leaf_pkg",
  "platforms" : [],
  "products" : [],
  "swiftLanguageVersions" : null,
  "targets" : [],
  "toolsVersion" : {
    "_version" : "5.9.0"
  }
}
"""

LEAF_PKG_DESC_JSON = """\
{
  "dependencies" : [],
  "name" : "leaf_pkg",
  "path" : "./",
  "targets" : []
}
"""
