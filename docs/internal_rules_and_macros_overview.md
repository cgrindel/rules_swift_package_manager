<!-- Generated with Stardoc, Do Not Edit! -->
# Internal Rules and Macros


The rules and macros described below are used by `rules_swift_package_manager` to build the external Swift packages.


On this page:

  * [generate_modulemap](#generate_modulemap)
  * [resource_bundle_accessor](#resource_bundle_accessor)
  * [resource_bundle_infoplist](#resource_bundle_infoplist)
  * [swift_package_stale](#swift_package_stale)
  * [swift_version_check](#swift_version_check)


<a id="generate_modulemap"></a>

## generate_modulemap

<pre>
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "generate_modulemap")

generate_modulemap(<a href="#generate_modulemap-name">name</a>, <a href="#generate_modulemap-deps">deps</a>, <a href="#generate_modulemap-hdrs">hdrs</a>, <a href="#generate_modulemap-module_name">module_name</a>)
</pre>

Generate a modulemap for an Objective-C module.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="generate_modulemap-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="generate_modulemap-deps"></a>deps |  The module maps that this module uses.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="generate_modulemap-hdrs"></a>hdrs |  The public headers for this module.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="generate_modulemap-module_name"></a>module_name |  The name of the module.   | String | optional |  `""`  |


<a id="resource_bundle_accessor"></a>

## resource_bundle_accessor

<pre>
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "resource_bundle_accessor")

resource_bundle_accessor(<a href="#resource_bundle_accessor-name">name</a>, <a href="#resource_bundle_accessor-bundle_name">bundle_name</a>)
</pre>

Generate a Swift file with an SPM-specific `Bundle.module` accessor.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="resource_bundle_accessor-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="resource_bundle_accessor-bundle_name"></a>bundle_name |  The name of the resource bundle.   | String | required |  |


<a id="resource_bundle_infoplist"></a>

## resource_bundle_infoplist

<pre>
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "resource_bundle_infoplist")

resource_bundle_infoplist(<a href="#resource_bundle_infoplist-name">name</a>, <a href="#resource_bundle_infoplist-region">region</a>)
</pre>

Generate an Info.plist for an SPM resource bundle.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="resource_bundle_infoplist-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="resource_bundle_infoplist-region"></a>region |  The localization/region value that should be embedded in the Info.plist.   | String | optional |  `"en"`  |


<a id="swift_package_stale"></a>

## swift_package_stale

<pre>
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "swift_package_stale")

swift_package_stale(<a href="#swift_package_stale-name">name</a>, <a href="#swift_package_stale-message">message</a>)
</pre>

Fails at analysis time with `message`.

Generated `select()` branches for stale cache slices point at this rule so that only builds that select a stale slice fail.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_package_stale-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="swift_package_stale-message"></a>message |  The failure message to report at analysis time.   | String | required |  |


<a id="swift_version_check"></a>

## swift_version_check

<pre>
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "swift_version_check")

swift_version_check(<a href="#swift_version_check-name">name</a>, <a href="#swift_version_check-slice_dir">slice_dir</a>, <a href="#swift_version_check-version_file">version_file</a>)
</pre>

Validates that the resolved Swift toolchain's `major.minor` version matches the version that produced a slice's `swift_deps_cache`. The check runs as a `_validation` output. `--@rules_swift_package_manager//:swift_version_check=off` skips it.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_version_check-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="swift_version_check-slice_dir"></a>slice_dir |  The slice directory, used in the failure message.   | String | required |  |
| <a id="swift_version_check-version_file"></a>version_file |  The cache's `swift_version.txt` (`major.minor.patch`).   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


