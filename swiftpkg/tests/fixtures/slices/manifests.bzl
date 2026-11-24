"""Manifest fixture text for the `MyPkg` slice tests.

Keep in sync with `dump.json` and `desc.json` in this directory.
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
