<!-- Generated with Stardoc, Do Not Edit! -->
# Rules and Macros


The rules described below back the `@swift_package` targets (`resolve`, `update` and `cache`) that maintain the Swift package slices.


On this page:

  * [swift_package_tool](#swift_package_tool)


<a id="swift_package_tool"></a>

## swift_package_tool

<pre>
load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_package_tool")

swift_package_tool(<a href="#swift_package_tool-name">name</a>, <a href="#swift_package_tool-data">data</a>)
</pre>

Runs `swift_deps_tool` with the `swift` wrapper from the Swift toolchain.

The generated `@swift_package` repository sets `args` to the tool command and its flags, as rendered by `swift_package_tool_args.render`. The rule passes the `swift` wrapper's runfiles path to the tool in the `RSPM_SWIFT_TOOL` environment variable.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_package_tool-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="swift_package_tool-data"></a>data |  Files that the tool reads at run time, such as the patch files referenced with `$(rootpath ...)` in `args`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


