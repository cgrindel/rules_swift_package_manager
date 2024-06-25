<!-- Generated with Stardoc, Do Not Edit! -->
# Repository Rules


The rules described below are used to build Swift packages and make their
products and targets available as Bazel targets.


On this page:

  * [local_swift_package](#local_swift_package)
  * [swift_package](#swift_package)


<a id="local_swift_package"></a>

## local_swift_package

<pre>
local_swift_package(<a href="#local_swift_package-name">name</a>, <a href="#local_swift_package-bazel_package_name">bazel_package_name</a>, <a href="#local_swift_package-dependencies_index">dependencies_index</a>, <a href="#local_swift_package-env">env</a>, <a href="#local_swift_package-path">path</a>, <a href="#local_swift_package-repo_mapping">repo_mapping</a>)
</pre>

Used to build a local Swift package.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="local_swift_package-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="local_swift_package-bazel_package_name"></a>bazel_package_name |  The short name for the Swift package's Bazel repository.   | String | optional | <code>""</code> |
| <a id="local_swift_package-dependencies_index"></a>dependencies_index |  A JSON file that contains a mapping of Swift products and Swift modules.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |
| <a id="local_swift_package-env"></a>env |  Environment variables that will be passed to the execution environments for this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM package description generation)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional | <code>{}</code> |
| <a id="local_swift_package-path"></a>path |  The path to the local Swift package directory. This can be an absolute path or a relative path to the workspace root.   | String | required |  |
| <a id="local_swift_package-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | required |  |


<a id="swift_package"></a>

## swift_package

<pre>
swift_package(<a href="#swift_package-name">name</a>, <a href="#swift_package-bazel_package_name">bazel_package_name</a>, <a href="#swift_package-branch">branch</a>, <a href="#swift_package-commit">commit</a>, <a href="#swift_package-dependencies_index">dependencies_index</a>, <a href="#swift_package-env">env</a>, <a href="#swift_package-init_submodules">init_submodules</a>,
              <a href="#swift_package-patch_args">patch_args</a>, <a href="#swift_package-patch_cmds">patch_cmds</a>, <a href="#swift_package-patch_cmds_win">patch_cmds_win</a>, <a href="#swift_package-patch_tool">patch_tool</a>, <a href="#swift_package-patches">patches</a>, <a href="#swift_package-recursive_init_submodules">recursive_init_submodules</a>,
              <a href="#swift_package-remote">remote</a>, <a href="#swift_package-repo_mapping">repo_mapping</a>, <a href="#swift_package-shallow_since">shallow_since</a>, <a href="#swift_package-tag">tag</a>, <a href="#swift_package-verbose">verbose</a>)
</pre>

Used to download and build an external Swift package.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_package-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="swift_package-bazel_package_name"></a>bazel_package_name |  The short name for the Swift package's Bazel repository.   | String | optional | <code>""</code> |
| <a id="swift_package-branch"></a>branch |  branch in the remote repository to checked out. Precisely one of branch, tag, or commit must be specified.   | String | optional | <code>""</code> |
| <a id="swift_package-commit"></a>commit |  The commit or revision to download from version control.   | String | required |  |
| <a id="swift_package-dependencies_index"></a>dependencies_index |  A JSON file that contains a mapping of Swift products and Swift modules.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |
| <a id="swift_package-env"></a>env |  Environment variables that will be passed to the execution environments for this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM package description generation)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional | <code>{}</code> |
| <a id="swift_package-init_submodules"></a>init_submodules |  Whether to clone submodules in the repository.   | Boolean | optional | <code>False</code> |
| <a id="swift_package-patch_args"></a>patch_args |  The arguments given to the patch tool. Defaults to -p0, however -p1 will usually be needed for patches generated by git. If multiple -p arguments are specified, the last one will take effect.If arguments other than -p are specified, Bazel will fall back to use patch command line tool instead of the Bazel-native patch implementation. When falling back to patch command line tool and patch_tool attribute is not specified, <code>patch</code> will be used.   | List of strings | optional | <code>["-p0"]</code> |
| <a id="swift_package-patch_cmds"></a>patch_cmds |  Sequence of Bash commands to be applied on Linux/Macos after patches are applied.   | List of strings | optional | <code>[]</code> |
| <a id="swift_package-patch_cmds_win"></a>patch_cmds_win |  Sequence of Powershell commands to be applied on Windows after patches are applied. If this attribute is not set, patch_cmds will be executed on Windows, which requires Bash binary to exist.   | List of strings | optional | <code>[]</code> |
| <a id="swift_package-patch_tool"></a>patch_tool |  The patch(1) utility to use. If this is specified, Bazel will use the specified patch tool instead of the Bazel-native patch implementation.   | String | optional | <code>""</code> |
| <a id="swift_package-patches"></a>patches |  A list of files that are to be applied as patches after extracting the archive. By default, it uses the Bazel-native patch implementation which doesn't support fuzz match and binary patch, but Bazel will fall back to use patch command line tool if <code>patch_tool</code> attribute is specified or there are arguments other than <code>-p</code> in <code>patch_args</code> attribute.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="swift_package-recursive_init_submodules"></a>recursive_init_submodules |  Whether to clone submodules recursively in the repository.   | Boolean | optional | <code>True</code> |
| <a id="swift_package-remote"></a>remote |  The version control location from where the repository should be downloaded.   | String | required |  |
| <a id="swift_package-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | required |  |
| <a id="swift_package-shallow_since"></a>shallow_since |  an optional date, not after the specified commit; the argument is not allowed if a tag is specified (which allows cloning with depth 1). Setting such a date close to the specified commit allows for a more shallow clone of the repository, saving bandwidth and wall-clock time.   | String | optional | <code>""</code> |
| <a id="swift_package-tag"></a>tag |  tag in the remote repository to checked out. Precisely one of branch, tag, or commit must be specified.   | String | optional | <code>""</code> |
| <a id="swift_package-verbose"></a>verbose |  -   | Boolean | optional | <code>False</code> |


