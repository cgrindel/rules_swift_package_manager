<!-- Generated with Stardoc, Do Not Edit! -->
# Repository Rules


The rules described below are used to build Swift packages and make their
products and targets available as Bazel targets.


On this page:

  * [local_swift_package](#local_swift_package)
  * [swift_package](#swift_package)
  * [registry_swift_package](#registry_swift_package)


<a id="local_swift_package"></a>

## local_swift_package

<pre>
load("@rules_swift_package_manager//swiftpkg:defs.bzl", "local_swift_package")

local_swift_package(<a href="#local_swift_package-name">name</a>, <a href="#local_swift_package-bazel_package_name">bazel_package_name</a>, <a href="#local_swift_package-dependencies_index">dependencies_index</a>, <a href="#local_swift_package-env">env</a>, <a href="#local_swift_package-env_inherit">env_inherit</a>, <a href="#local_swift_package-path">path</a>,
                    <a href="#local_swift_package-repo_mapping">repo_mapping</a>)
</pre>

Used to build a local Swift package.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="local_swift_package-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="local_swift_package-bazel_package_name"></a>bazel_package_name |  The short name for the Swift package's Bazel repository.   | String | optional |  `""`  |
| <a id="local_swift_package-dependencies_index"></a>dependencies_index |  A JSON file that contains a mapping of Swift products and Swift modules.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="local_swift_package-env"></a>env |  Environment variables that will be passed to the execution environments for this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM package description generation)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="local_swift_package-env_inherit"></a>env_inherit |  Environment variables to inherit from the external environment that will be passed to the execution environments for this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM package description generation)   | List of strings | optional |  `[]`  |
| <a id="local_swift_package-path"></a>path |  The path to the local Swift package directory. This can be an absolute path or a relative path to the workspace root.   | String | required |  |
| <a id="local_swift_package-repo_mapping"></a>repo_mapping |  In `WORKSPACE` context only: a dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.<br><br>For example, an entry `"@foo": "@bar"` declares that, for any time this repository depends on `@foo` (such as a dependency on `@foo//some:target`, it should actually resolve that dependency within globally-declared `@bar` (`@bar//some:target`).<br><br>This attribute is _not_ supported in `MODULE.bazel` context (when invoking a repository rule inside a module extension's implementation function).   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  |


<a id="registry_swift_package"></a>

## registry_swift_package

<pre>
load("@rules_swift_package_manager//swiftpkg:defs.bzl", "registry_swift_package")

registry_swift_package(<a href="#registry_swift_package-name">name</a>, <a href="#registry_swift_package-bazel_package_name">bazel_package_name</a>, <a href="#registry_swift_package-dependencies_index">dependencies_index</a>, <a href="#registry_swift_package-env">env</a>, <a href="#registry_swift_package-env_inherit">env_inherit</a>, <a href="#registry_swift_package-id">id</a>,
                       <a href="#registry_swift_package-registries">registries</a>, <a href="#registry_swift_package-replace_scm_with_registry">replace_scm_with_registry</a>, <a href="#registry_swift_package-repo_mapping">repo_mapping</a>, <a href="#registry_swift_package-resolved">resolved</a>, <a href="#registry_swift_package-version">version</a>)
</pre>

Used to download and build an external Swift package from a registry.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="registry_swift_package-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="registry_swift_package-bazel_package_name"></a>bazel_package_name |  The short name for the Swift package's Bazel repository.   | String | optional |  `""`  |
| <a id="registry_swift_package-dependencies_index"></a>dependencies_index |  A JSON file that contains a mapping of Swift products and Swift modules.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="registry_swift_package-env"></a>env |  Environment variables that will be passed to the execution environments for this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM package description generation)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="registry_swift_package-env_inherit"></a>env_inherit |  Environment variables to inherit from the external environment that will be passed to the execution environments for this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM package description generation)   | List of strings | optional |  `[]`  |
| <a id="registry_swift_package-id"></a>id |  The package identifier.   | String | required |  |
| <a id="registry_swift_package-registries"></a>registries |  A `registries.json` file that defines the configured Swift package registries.<br><br>The `registries.json` file is used when resolving Swift packages from a Swift package registry. It is created by Swift Package Manager when using the `swift package-registry` commands.<br><br>When using the `swift_package_tool` rules, this file is symlinked to the `config_path` directory defined in the `configure_swift_package` tag. If not using the `swift_package_tool` rules, the file must be in one of Swift Package Manager's search paths or in the manually specified `--config-path` directory.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="registry_swift_package-replace_scm_with_registry"></a>replace_scm_with_registry |  When enabled replaces SCM identities in dependencies package description with identities from the registries.<br><br>Using this option requires that the registries provide `repositoryURLs` as metadata for the package.<br><br>When `True` the equivalent `--replace-scm-with-registry` option must be used with the Swift Package Manager CLI (or `swift_package` rule) so that the `resolved` file includes the version and identity information from the registry.<br><br>For more information see the [Swift Package Manager documentation](https://github.com/swiftlang/swift-package-manager/blob/swift-6.0.1-RELEASE/Documentation/PackageRegistry/Registry.md#45-lookup-package-identifiers-registered-for-a-url).   | Boolean | optional |  `False`  |
| <a id="registry_swift_package-repo_mapping"></a>repo_mapping |  In `WORKSPACE` context only: a dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.<br><br>For example, an entry `"@foo": "@bar"` declares that, for any time this repository depends on `@foo` (such as a dependency on `@foo//some:target`, it should actually resolve that dependency within globally-declared `@bar` (`@bar//some:target`).<br><br>This attribute is _not_ supported in `MODULE.bazel` context (when invoking a repository rule inside a module extension's implementation function).   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  |
| <a id="registry_swift_package-resolved"></a>resolved |  A `Package.resolved`, used to de-duplicate dependency identities when `use_registry_identity_for_scm` or `replace_scm_with_registry` is enabled.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="registry_swift_package-version"></a>version |  The package version.   | String | required |  |


<a id="swift_package"></a>

## swift_package

<pre>
load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_package")

swift_package(<a href="#swift_package-name">name</a>, <a href="#swift_package-bazel_package_name">bazel_package_name</a>, <a href="#swift_package-branch">branch</a>, <a href="#swift_package-commit">commit</a>, <a href="#swift_package-dependencies_index">dependencies_index</a>, <a href="#swift_package-env">env</a>, <a href="#swift_package-env_inherit">env_inherit</a>,
              <a href="#swift_package-init_submodules">init_submodules</a>, <a href="#swift_package-patch_args">patch_args</a>, <a href="#swift_package-patch_cmds">patch_cmds</a>, <a href="#swift_package-patch_cmds_win">patch_cmds_win</a>, <a href="#swift_package-patch_tool">patch_tool</a>, <a href="#swift_package-patches">patches</a>,
              <a href="#swift_package-publicly_expose_all_targets">publicly_expose_all_targets</a>, <a href="#swift_package-recursive_init_submodules">recursive_init_submodules</a>, <a href="#swift_package-registries">registries</a>, <a href="#swift_package-remote">remote</a>,
              <a href="#swift_package-replace_scm_with_registry">replace_scm_with_registry</a>, <a href="#swift_package-repo_mapping">repo_mapping</a>, <a href="#swift_package-shallow_since">shallow_since</a>, <a href="#swift_package-tag">tag</a>, <a href="#swift_package-verbose">verbose</a>, <a href="#swift_package-version">version</a>)
</pre>

Used to download and build an external Swift package.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_package-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="swift_package-bazel_package_name"></a>bazel_package_name |  The short name for the Swift package's Bazel repository.   | String | optional |  `""`  |
| <a id="swift_package-branch"></a>branch |  branch in the remote repository to checked out. Precisely one of branch, tag, or commit must be specified.   | String | optional |  `""`  |
| <a id="swift_package-commit"></a>commit |  The commit or revision to download from version control.   | String | required |  |
| <a id="swift_package-dependencies_index"></a>dependencies_index |  A JSON file that contains a mapping of Swift products and Swift modules.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="swift_package-env"></a>env |  Environment variables that will be passed to the execution environments for this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM package description generation)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="swift_package-env_inherit"></a>env_inherit |  Environment variables to inherit from the external environment that will be passed to the execution environments for this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM package description generation)   | List of strings | optional |  `[]`  |
| <a id="swift_package-init_submodules"></a>init_submodules |  Whether to clone submodules in the repository.   | Boolean | optional |  `False`  |
| <a id="swift_package-patch_args"></a>patch_args |  The arguments given to the patch tool. Defaults to -p0, however -p1 will usually be needed for patches generated by git. If multiple -p arguments are specified, the last one will take effect.If arguments other than -p are specified, Bazel will fall back to use patch command line tool instead of the Bazel-native patch implementation. When falling back to patch command line tool and patch_tool attribute is not specified, `patch` will be used.   | List of strings | optional |  `["-p0"]`  |
| <a id="swift_package-patch_cmds"></a>patch_cmds |  Sequence of Bash commands to be applied on Linux/Macos after patches are applied.   | List of strings | optional |  `[]`  |
| <a id="swift_package-patch_cmds_win"></a>patch_cmds_win |  Sequence of Powershell commands to be applied on Windows after patches are applied. If this attribute is not set, patch_cmds will be executed on Windows, which requires Bash binary to exist.   | List of strings | optional |  `[]`  |
| <a id="swift_package-patch_tool"></a>patch_tool |  The patch(1) utility to use. If this is specified, Bazel will use the specified patch tool instead of the Bazel-native patch implementation.   | String | optional |  `""`  |
| <a id="swift_package-patches"></a>patches |  A list of files that are to be applied as patches after extracting the archive. By default, it uses the Bazel-native patch implementation which doesn't support fuzz match and binary patch, but Bazel will fall back to use patch command line tool if `patch_tool` attribute is specified or there are arguments other than `-p` in `patch_args` attribute.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="swift_package-publicly_expose_all_targets"></a>publicly_expose_all_targets |  Allows to expose internal build targets required for package compilation. The structure and labels of exposed targets may change in future releases without requiring a major version bump.   | Boolean | optional |  `False`  |
| <a id="swift_package-recursive_init_submodules"></a>recursive_init_submodules |  Whether to clone submodules recursively in the repository.   | Boolean | optional |  `True`  |
| <a id="swift_package-registries"></a>registries |  The registries JSON file for the package if using Swift Package Registries.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="swift_package-remote"></a>remote |  The version control location from where the repository should be downloaded.   | String | required |  |
| <a id="swift_package-replace_scm_with_registry"></a>replace_scm_with_registry |  Whether to replace SCM references with registry references. Only used if `registries` is provided.   | Boolean | optional |  `False`  |
| <a id="swift_package-repo_mapping"></a>repo_mapping |  In `WORKSPACE` context only: a dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.<br><br>For example, an entry `"@foo": "@bar"` declares that, for any time this repository depends on `@foo` (such as a dependency on `@foo//some:target`, it should actually resolve that dependency within globally-declared `@bar` (`@bar//some:target`).<br><br>This attribute is _not_ supported in `MODULE.bazel` context (when invoking a repository rule inside a module extension's implementation function).   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  |
| <a id="swift_package-shallow_since"></a>shallow_since |  an optional date, not after the specified commit; the argument is not allowed if a tag is specified (which allows cloning with depth 1). Setting such a date close to the specified commit allows for a more shallow clone of the repository, saving bandwidth and wall-clock time.   | String | optional |  `""`  |
| <a id="swift_package-tag"></a>tag |  tag in the remote repository to checked out. Precisely one of branch, tag, or commit must be specified.   | String | optional |  `""`  |
| <a id="swift_package-verbose"></a>verbose |  -   | Boolean | optional |  `False`  |
| <a id="swift_package-version"></a>version |  The resolved version of the package.   | String | optional |  `""`  |


