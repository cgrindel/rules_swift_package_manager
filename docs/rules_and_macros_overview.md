<!-- Generated with Stardoc, Do Not Edit! -->
# Rules and Macros


The rules and macros described below are used to define Gazelle targets to aid in the generation and maintenance of Swift package dependencies.


On this page:

  * [swift_deps_index](#swift_deps_index)


<a id="swift_deps_index"></a>

## swift_deps_index

<pre>
load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_deps_index")

swift_deps_index(<a href="#swift_deps_index-name">name</a>, <a href="#swift_deps_index-kwargs">**kwargs</a>)
</pre>

Moved to swift_gazelle_plugin.

Load `swift_deps_index` from
`@swift_gazelle_plugin//swift_deps_index:defs.bzl` and point it at the
`swift_deps_info` repository:

```starlark
swift_deps_index(
    name = "swift_deps_index",
    swift_deps_info = "@swift_deps_info",
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="swift_deps_index-name"></a>name |  A unique name for this target.   |  none |
| <a id="swift_deps_index-kwargs"></a>kwargs |  Ignored.   |  none |


