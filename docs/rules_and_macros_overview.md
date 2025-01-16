<!-- Generated with Stardoc, Do Not Edit! -->
# Rules and Macros


The rules and macros described below are used to define Gazelle targets to aid in the generation and maintenance of Swift package dependencies.


On this page:

  * [swift_deps_index](#swift_deps_index)


<a id="swift_deps_index"></a>

## swift_deps_index

<pre>
load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_deps_index")

swift_deps_index(<a href="#swift_deps_index-name">name</a>, <a href="#swift_deps_index-direct_dep_pkg_infos">direct_dep_pkg_infos</a>)
</pre>

Generates a Swift dependencies index file that is used by other tooling (e.g., Swift Gazelle plugin).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps_index-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="swift_deps_index-direct_dep_pkg_infos"></a>direct_dep_pkg_infos |  A `dict` where the key is the label for a Swift package's `pkg_info.json` file and the value is the Swift package's identity value.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: Label -> String</a> | optional |  `{}`  |


