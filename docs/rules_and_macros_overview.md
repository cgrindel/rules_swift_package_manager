<!-- Generated with Stardoc, Do Not Edit! -->
# Rules and Macros


The rules and macros described below are used to define Gazelle targets to aid in the generation and maintenance of Swift package dependencies.


On this page:

  * [swift_deps_index](#swift_deps_index)


<a id="swift_deps_index"></a>

## swift_deps_index

<pre>
swift_deps_index(<a href="#swift_deps_index-name">name</a>, <a href="#swift_deps_index-direct_dep_pkg_infos">direct_dep_pkg_infos</a>)
</pre>

Generates a Swift dependencies index file that is used by other tooling (e.g., Swift Gazelle plugin).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps_index-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="swift_deps_index-direct_dep_pkg_infos"></a>direct_dep_pkg_infos |  The <code>pkg_info.json</code> files for the direct dependencies.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |


