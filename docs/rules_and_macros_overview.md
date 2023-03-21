<!-- Generated with Stardoc, Do Not Edit! -->
# Rules and Macros


The rules and macros described below are used to define Gazelle targets to aid in the generation and maintenance of Swift package dependencies.


On this page:

  * [swift_update_packages](#swift_update_packages)


<a id="swift_update_packages"></a>

## swift_update_packages

<pre>
swift_update_packages(<a href="#swift_update_packages-name">name</a>, <a href="#swift_update_packages-gazelle">gazelle</a>, <a href="#swift_update_packages-package_manifest">package_manifest</a>, <a href="#swift_update_packages-swift_deps">swift_deps</a>, <a href="#swift_update_packages-swift_deps_fn">swift_deps_fn</a>, <a href="#swift_update_packages-swift_deps_index">swift_deps_index</a>,
                      <a href="#swift_update_packages-print_bzlmod_stanzas">print_bzlmod_stanzas</a>, <a href="#swift_update_packages-update_bzlmod_stanzas">update_bzlmod_stanzas</a>, <a href="#swift_update_packages-bazel_module">bazel_module</a>, <a href="#swift_update_packages-kwargs">kwargs</a>)
</pre>

Defines gazelle update-repos targets that are used to resolve and update     Swift package dependencies.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="swift_update_packages-name"></a>name |  The name of the <code>resolve</code> target as a <code>string</code>. The target name for the <code>update</code> target is derived from this value by appending <code>_to_latest</code>.   |  none |
| <a id="swift_update_packages-gazelle"></a>gazelle |  The label to <code>gazelle_binary</code> that includes the <code>swift_bazel</code> Gazelle extension.   |  none |
| <a id="swift_update_packages-package_manifest"></a>package_manifest |  Optional. The name of the Swift package manifest file as a <code>string</code>.   |  <code>"Package.swift"</code> |
| <a id="swift_update_packages-swift_deps"></a>swift_deps |  Optional. The name of the Starlark file that should be updated with the Swift package dependencies as a <code>string</code>.   |  <code>"swift_deps.bzl"</code> |
| <a id="swift_update_packages-swift_deps_fn"></a>swift_deps_fn |  Optional. The name of the Starlark function in the <code>swift_deps</code> file that should be updated with the Swift package dependencies as a <code>string</code>.   |  <code>"swift_dependencies"</code> |
| <a id="swift_update_packages-swift_deps_index"></a>swift_deps_index |  Optional. The relative path to the Swift dependencies index JSON file. This path is relative to the repository root, not the location of this declaration.   |  <code>"swift_deps_index.json"</code> |
| <a id="swift_update_packages-print_bzlmod_stanzas"></a>print_bzlmod_stanzas |  Optional. Determines whether the Gazelle extension prints out bzlmod Starlark code that can be pasted into your <code>MODULE.bazel</code>.   |  <code>False</code> |
| <a id="swift_update_packages-update_bzlmod_stanzas"></a>update_bzlmod_stanzas |  Optional. Determines whether the Gazelle extension adds/updates the bzlmod Starlark code to MODULE.bazel.   |  <code>False</code> |
| <a id="swift_update_packages-bazel_module"></a>bazel_module |  Optional. The relative path to the <code>MODULE.bazel</code> file.   |  <code>"MODULE.bazel"</code> |
| <a id="swift_update_packages-kwargs"></a>kwargs |  Attributes that are passed along to the gazelle declarations.   |  none |


