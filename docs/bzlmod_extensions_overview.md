<!-- Generated with Stardoc, Do Not Edit! -->
# Bazel Modules (bzlmod) Extensions


The bzlmod extensions described below are used by `rules_swift_package_manager` to customize the build of the external Swift packages.

On this page:

  * [swift_deps](#swift_deps)


<a id="swift_deps"></a>

## swift_deps

<pre>
swift_deps = use_extension("@rules_swift_package_manager//:extensions.bzl", "swift_deps")
swift_deps.bazel_target_add(<a href="#swift_deps.bazel_target_add-attr">attr</a>, <a href="#swift_deps.bazel_target_add-target">target</a>, <a href="#swift_deps.bazel_target_add-values">values</a>)
swift_deps.bazel_target_add_select(<a href="#swift_deps.bazel_target_add_select-attr">attr</a>, <a href="#swift_deps.bazel_target_add_select-target">target</a>, <a href="#swift_deps.bazel_target_add_select-values">values</a>)
swift_deps.bazel_target_set_bool(<a href="#swift_deps.bazel_target_set_bool-attr">attr</a>, <a href="#swift_deps.bazel_target_set_bool-target">target</a>, <a href="#swift_deps.bazel_target_set_bool-value">value</a>)
swift_deps.bazel_target_set_int(<a href="#swift_deps.bazel_target_set_int-attr">attr</a>, <a href="#swift_deps.bazel_target_set_int-target">target</a>, <a href="#swift_deps.bazel_target_set_int-value">value</a>)
swift_deps.bazel_target_set_select_bool_dict(<a href="#swift_deps.bazel_target_set_select_bool_dict-attr">attr</a>, <a href="#swift_deps.bazel_target_set_select_bool_dict-target">target</a>, <a href="#swift_deps.bazel_target_set_select_bool_dict-values">values</a>)
swift_deps.bazel_target_set_select_int_dict(<a href="#swift_deps.bazel_target_set_select_int_dict-attr">attr</a>, <a href="#swift_deps.bazel_target_set_select_int_dict-target">target</a>, <a href="#swift_deps.bazel_target_set_select_int_dict-values">values</a>)
swift_deps.bazel_target_set_select_string_dict(<a href="#swift_deps.bazel_target_set_select_string_dict-attr">attr</a>, <a href="#swift_deps.bazel_target_set_select_string_dict-target">target</a>, <a href="#swift_deps.bazel_target_set_select_string_dict-values">values</a>)
swift_deps.bazel_target_set_select_string_list_dict(<a href="#swift_deps.bazel_target_set_select_string_list_dict-attr">attr</a>, <a href="#swift_deps.bazel_target_set_select_string_list_dict-target">target</a>, <a href="#swift_deps.bazel_target_set_select_string_list_dict-values">values</a>)
swift_deps.bazel_target_set_string(<a href="#swift_deps.bazel_target_set_string-attr">attr</a>, <a href="#swift_deps.bazel_target_set_string-target">target</a>, <a href="#swift_deps.bazel_target_set_string-value">value</a>)
swift_deps.bazel_target_set_string_dict(<a href="#swift_deps.bazel_target_set_string_dict-attr">attr</a>, <a href="#swift_deps.bazel_target_set_string_dict-target">target</a>, <a href="#swift_deps.bazel_target_set_string_dict-value">value</a>)
swift_deps.bazel_target_set_string_list(<a href="#swift_deps.bazel_target_set_string_list-attr">attr</a>, <a href="#swift_deps.bazel_target_set_string_list-target">target</a>, <a href="#swift_deps.bazel_target_set_string_list-value">value</a>)
swift_deps.configure_package(<a href="#swift_deps.configure_package-name">name</a>, <a href="#swift_deps.configure_package-build_file">build_file</a>, <a href="#swift_deps.configure_package-init_submodules">init_submodules</a>, <a href="#swift_deps.configure_package-patch_args">patch_args</a>, <a href="#swift_deps.configure_package-patch_cmds">patch_cmds</a>,
                             <a href="#swift_deps.configure_package-patch_cmds_win">patch_cmds_win</a>, <a href="#swift_deps.configure_package-patch_tool">patch_tool</a>, <a href="#swift_deps.configure_package-patches">patches</a>, <a href="#swift_deps.configure_package-publicly_expose_all_targets">publicly_expose_all_targets</a>,
                             <a href="#swift_deps.configure_package-recursive_init_submodules">recursive_init_submodules</a>, <a href="#swift_deps.configure_package-target_deps">target_deps</a>)
swift_deps.configure_swift_package(<a href="#swift_deps.configure_swift_package-build_path">build_path</a>, <a href="#swift_deps.configure_swift_package-cache_path">cache_path</a>, <a href="#swift_deps.configure_swift_package-config_path">config_path</a>, <a href="#swift_deps.configure_swift_package-dependency_caching">dependency_caching</a>,
                                   <a href="#swift_deps.configure_swift_package-manifest_cache">manifest_cache</a>, <a href="#swift_deps.configure_swift_package-manifest_caching">manifest_caching</a>, <a href="#swift_deps.configure_swift_package-replace_scm_with_registry">replace_scm_with_registry</a>,
                                   <a href="#swift_deps.configure_swift_package-security_path">security_path</a>, <a href="#swift_deps.configure_swift_package-use_registry_identity_for_scm">use_registry_identity_for_scm</a>)
swift_deps.from_package(<a href="#swift_deps.from_package-cached_json_directory">cached_json_directory</a>, <a href="#swift_deps.from_package-declare_swift_deps_info">declare_swift_deps_info</a>, <a href="#swift_deps.from_package-declare_swift_package">declare_swift_package</a>, <a href="#swift_deps.from_package-env">env</a>,
                        <a href="#swift_deps.from_package-env_inherit">env_inherit</a>, <a href="#swift_deps.from_package-netrc">netrc</a>, <a href="#swift_deps.from_package-registries">registries</a>, <a href="#swift_deps.from_package-resolve_transitive_local_dependencies">resolve_transitive_local_dependencies</a>,
                        <a href="#swift_deps.from_package-resolved">resolved</a>, <a href="#swift_deps.from_package-swift">swift</a>)
</pre>


**TAG CLASSES**

<a id="swift_deps.bazel_target_add"></a>

### bazel_target_add

Append values to a list attribute on a generated declaration.

The values are appended after the generated values, so options that follow last-option-wins semantics (e.g. `copts`) override the generated ones.

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule does not understand fails when Bazel loads the generated `BUILD.bazel` file, with Bazel's own error message. Use at your own risk.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.bazel_target_add-attr"></a>attr |  The name of the attribute to modify, such as `copts`. The `name` attribute may not be modified.   | String | required |  |
| <a id="swift_deps.bazel_target_add-target"></a>target |  A label `string` naming a declaration in a generated repository, such as `@swiftpkg_foo//:Bar.rspm.__impl`. Every generated declaration lives in the root package of its repository, so the label must be of the form `@repo_name//:target_name`.   | String | required |  |
| <a id="swift_deps.bazel_target_add-values"></a>values |  The values to append. At least one value is required. If the attribute is absent, it is created with these values.<br><br>The values are written into the generated `BUILD.bazel` file verbatim. Label values are not remapped, so a value such as `//:my_lib` resolves inside the generated repository, not your root module. Use `@@//:my_lib` to name a target in the main repository.   | List of strings | required |  |

<a id="swift_deps.bazel_target_add_select"></a>

### bazel_target_add_select

Append a `select()` to an attribute on a generated declaration.

The generated value is preserved: the attribute renders as `<generated> + select({...})`.

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule does not understand fails when Bazel loads the generated `BUILD.bazel` file, with Bazel's own error message. Use at your own risk.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.bazel_target_add_select-attr"></a>attr |  The name of the attribute to modify, such as `copts`. The `name` attribute may not be modified.   | String | required |  |
| <a id="swift_deps.bazel_target_add_select-target"></a>target |  A label `string` naming a declaration in a generated repository, such as `@swiftpkg_foo//:Bar.rspm.__impl`. Every generated declaration lives in the root package of its repository, so the label must be of the form `@repo_name//:target_name`.   | String | required |  |
| <a id="swift_deps.bazel_target_add_select-values"></a>values |  The `select()` branches, whose values are `list` values of `string` values. Keys are absolute condition labels; a key that is relative to the main repository (e.g. `//:release_build`) is canonicalized (e.g. `@@//:release_build`) so that it still resolves from inside the generated repository. A key that names an apparent repository (a single `@`, e.g. `@some_repo//:setting`) is rejected, because it would be resolved against the generated repository's repository mapping; use a canonical label (e.g. `@@some_repo+//:setting`) instead. A `//conditions:default` branch with no values is added when one is not provided.<br><br>The values are written into the generated `BUILD.bazel` file verbatim. Label values are not remapped, so a value such as `//:my_lib` resolves inside the generated repository, not your root module. Use `@@//:my_lib` to name a target in the main repository.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> List of strings</a> | required |  |

<a id="swift_deps.bazel_target_set_bool"></a>

### bazel_target_set_bool

Replace (or create) an attribute on a generated declaration.

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule does not understand fails when Bazel loads the generated `BUILD.bazel` file, with Bazel's own error message. Use at your own risk.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.bazel_target_set_bool-attr"></a>attr |  The name of the attribute to modify, such as `copts`. The `name` attribute may not be modified.   | String | required |  |
| <a id="swift_deps.bazel_target_set_bool-target"></a>target |  A label `string` naming a declaration in a generated repository, such as `@swiftpkg_foo//:Bar.rspm.__impl`. Every generated declaration lives in the root package of its repository, so the label must be of the form `@repo_name//:target_name`.   | String | required |  |
| <a id="swift_deps.bazel_target_set_bool-value"></a>value |  The replacement value as a `bool`.   | Boolean | required |  |

<a id="swift_deps.bazel_target_set_int"></a>

### bazel_target_set_int

Replace (or create) an attribute on a generated declaration.

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule does not understand fails when Bazel loads the generated `BUILD.bazel` file, with Bazel's own error message. Use at your own risk.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.bazel_target_set_int-attr"></a>attr |  The name of the attribute to modify, such as `copts`. The `name` attribute may not be modified.   | String | required |  |
| <a id="swift_deps.bazel_target_set_int-target"></a>target |  A label `string` naming a declaration in a generated repository, such as `@swiftpkg_foo//:Bar.rspm.__impl`. Every generated declaration lives in the root package of its repository, so the label must be of the form `@repo_name//:target_name`.   | String | required |  |
| <a id="swift_deps.bazel_target_set_int-value"></a>value |  The replacement value as an `int`.   | Integer | required |  |

<a id="swift_deps.bazel_target_set_select_bool_dict"></a>

### bazel_target_set_select_bool_dict

Replace (or create) an attribute on a generated declaration with a `select()`.

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule does not understand fails when Bazel loads the generated `BUILD.bazel` file, with Bazel's own error message. Use at your own risk.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.bazel_target_set_select_bool_dict-attr"></a>attr |  The name of the attribute to modify, such as `copts`. The `name` attribute may not be modified.   | String | required |  |
| <a id="swift_deps.bazel_target_set_select_bool_dict-target"></a>target |  A label `string` naming a declaration in a generated repository, such as `@swiftpkg_foo//:Bar.rspm.__impl`. Every generated declaration lives in the root package of its repository, so the label must be of the form `@repo_name//:target_name`.   | String | required |  |
| <a id="swift_deps.bazel_target_set_select_bool_dict-values"></a>values |  The `select()` branches, whose values are `string` values that are converted to a `bool`. Each value must be exactly `True` or `False`, spelled the way Starlark spells them; any other value fails when the module extension is evaluated. Keys are absolute condition labels; a key that is relative to the main repository (e.g. `//:release_build`) is canonicalized (e.g. `@@//:release_build`) so that it still resolves from inside the generated repository. A key that names an apparent repository (a single `@`, e.g. `@some_repo//:setting`) is rejected, because it would be resolved against the generated repository's repository mapping; use a canonical label (e.g. `@@some_repo+//:setting`) instead. No `//conditions:default` branch is added for you.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | required |  |

<a id="swift_deps.bazel_target_set_select_int_dict"></a>

### bazel_target_set_select_int_dict

Replace (or create) an attribute on a generated declaration with a `select()`.

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule does not understand fails when Bazel loads the generated `BUILD.bazel` file, with Bazel's own error message. Use at your own risk.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.bazel_target_set_select_int_dict-attr"></a>attr |  The name of the attribute to modify, such as `copts`. The `name` attribute may not be modified.   | String | required |  |
| <a id="swift_deps.bazel_target_set_select_int_dict-target"></a>target |  A label `string` naming a declaration in a generated repository, such as `@swiftpkg_foo//:Bar.rspm.__impl`. Every generated declaration lives in the root package of its repository, so the label must be of the form `@repo_name//:target_name`.   | String | required |  |
| <a id="swift_deps.bazel_target_set_select_int_dict-values"></a>values |  The `select()` branches, whose values are `string` values that are converted to an `int`. Each value must be digits with an optional leading `-`; any other value fails when the module extension is evaluated. Keys are absolute condition labels; a key that is relative to the main repository (e.g. `//:release_build`) is canonicalized (e.g. `@@//:release_build`) so that it still resolves from inside the generated repository. A key that names an apparent repository (a single `@`, e.g. `@some_repo//:setting`) is rejected, because it would be resolved against the generated repository's repository mapping; use a canonical label (e.g. `@@some_repo+//:setting`) instead. No `//conditions:default` branch is added for you.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | required |  |

<a id="swift_deps.bazel_target_set_select_string_dict"></a>

### bazel_target_set_select_string_dict

Replace (or create) an attribute on a generated declaration with a `select()`.

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule does not understand fails when Bazel loads the generated `BUILD.bazel` file, with Bazel's own error message. Use at your own risk.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.bazel_target_set_select_string_dict-attr"></a>attr |  The name of the attribute to modify, such as `copts`. The `name` attribute may not be modified.   | String | required |  |
| <a id="swift_deps.bazel_target_set_select_string_dict-target"></a>target |  A label `string` naming a declaration in a generated repository, such as `@swiftpkg_foo//:Bar.rspm.__impl`. Every generated declaration lives in the root package of its repository, so the label must be of the form `@repo_name//:target_name`.   | String | required |  |
| <a id="swift_deps.bazel_target_set_select_string_dict-values"></a>values |  The `select()` branches, whose values are `string` values. Keys are absolute condition labels; a key that is relative to the main repository (e.g. `//:release_build`) is canonicalized (e.g. `@@//:release_build`) so that it still resolves from inside the generated repository. A key that names an apparent repository (a single `@`, e.g. `@some_repo//:setting`) is rejected, because it would be resolved against the generated repository's repository mapping; use a canonical label (e.g. `@@some_repo+//:setting`) instead. No `//conditions:default` branch is added for you. The values are written into the generated `BUILD.bazel` file verbatim. Label values are not remapped, so a value such as `//:my_lib` resolves inside the generated repository, not your root module. Use `@@//:my_lib` to name a target in the main repository.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | required |  |

<a id="swift_deps.bazel_target_set_select_string_list_dict"></a>

### bazel_target_set_select_string_list_dict

Replace (or create) an attribute on a generated declaration with a `select()`.

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule does not understand fails when Bazel loads the generated `BUILD.bazel` file, with Bazel's own error message. Use at your own risk.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.bazel_target_set_select_string_list_dict-attr"></a>attr |  The name of the attribute to modify, such as `copts`. The `name` attribute may not be modified.   | String | required |  |
| <a id="swift_deps.bazel_target_set_select_string_list_dict-target"></a>target |  A label `string` naming a declaration in a generated repository, such as `@swiftpkg_foo//:Bar.rspm.__impl`. Every generated declaration lives in the root package of its repository, so the label must be of the form `@repo_name//:target_name`.   | String | required |  |
| <a id="swift_deps.bazel_target_set_select_string_list_dict-values"></a>values |  The `select()` branches, whose values are `list` values of `string` values. Keys are absolute condition labels; a key that is relative to the main repository (e.g. `//:release_build`) is canonicalized (e.g. `@@//:release_build`) so that it still resolves from inside the generated repository. A key that names an apparent repository (a single `@`, e.g. `@some_repo//:setting`) is rejected, because it would be resolved against the generated repository's repository mapping; use a canonical label (e.g. `@@some_repo+//:setting`) instead. No `//conditions:default` branch is added for you. The values are written into the generated `BUILD.bazel` file verbatim. Label values are not remapped, so a value such as `//:my_lib` resolves inside the generated repository, not your root module. Use `@@//:my_lib` to name a target in the main repository.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> List of strings</a> | required |  |

<a id="swift_deps.bazel_target_set_string"></a>

### bazel_target_set_string

Replace (or create) an attribute on a generated declaration.

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule does not understand fails when Bazel loads the generated `BUILD.bazel` file, with Bazel's own error message. Use at your own risk.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.bazel_target_set_string-attr"></a>attr |  The name of the attribute to modify, such as `copts`. The `name` attribute may not be modified.   | String | required |  |
| <a id="swift_deps.bazel_target_set_string-target"></a>target |  A label `string` naming a declaration in a generated repository, such as `@swiftpkg_foo//:Bar.rspm.__impl`. Every generated declaration lives in the root package of its repository, so the label must be of the form `@repo_name//:target_name`.   | String | required |  |
| <a id="swift_deps.bazel_target_set_string-value"></a>value |  The replacement value as a `string`. An empty `string` is allowed.<br><br>The value is written into the generated `BUILD.bazel` file verbatim. Label values are not remapped, so a value such as `//:my_lib` resolves inside the generated repository, not your root module. Use `@@//:my_lib` to name a target in the main repository.   | String | required |  |

<a id="swift_deps.bazel_target_set_string_dict"></a>

### bazel_target_set_string_dict

Replace (or create) an attribute on a generated declaration.

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule does not understand fails when Bazel loads the generated `BUILD.bazel` file, with Bazel's own error message. Use at your own risk.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.bazel_target_set_string_dict-attr"></a>attr |  The name of the attribute to modify, such as `copts`. The `name` attribute may not be modified.   | String | required |  |
| <a id="swift_deps.bazel_target_set_string_dict-target"></a>target |  A label `string` naming a declaration in a generated repository, such as `@swiftpkg_foo//:Bar.rspm.__impl`. Every generated declaration lives in the root package of its repository, so the label must be of the form `@repo_name//:target_name`.   | String | required |  |
| <a id="swift_deps.bazel_target_set_string_dict-value"></a>value |  The replacement value as a `dict` of `string` keys to `string` values. An empty `dict` is allowed and clears the attribute.<br><br>The values are written into the generated `BUILD.bazel` file verbatim. Label values are not remapped, so a value such as `//:my_lib` resolves inside the generated repository, not your root module. Use `@@//:my_lib` to name a target in the main repository.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | required |  |

<a id="swift_deps.bazel_target_set_string_list"></a>

### bazel_target_set_string_list

Replace (or create) an attribute on a generated declaration.

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule does not understand fails when Bazel loads the generated `BUILD.bazel` file, with Bazel's own error message. Use at your own risk.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.bazel_target_set_string_list-attr"></a>attr |  The name of the attribute to modify, such as `copts`. The `name` attribute may not be modified.   | String | required |  |
| <a id="swift_deps.bazel_target_set_string_list-target"></a>target |  A label `string` naming a declaration in a generated repository, such as `@swiftpkg_foo//:Bar.rspm.__impl`. Every generated declaration lives in the root package of its repository, so the label must be of the form `@repo_name//:target_name`.   | String | required |  |
| <a id="swift_deps.bazel_target_set_string_list-value"></a>value |  The replacement value as a `list` of `string` values. An empty `list` is allowed and clears the attribute.<br><br>The values are written into the generated `BUILD.bazel` file verbatim. Label values are not remapped, so a value such as `//:my_lib` resolves inside the generated repository, not your root module. Use `@@//:my_lib` to name a target in the main repository.   | List of strings | required |  |

<a id="swift_deps.configure_package"></a>

### configure_package

Used to add or override settings for a particular Swift package.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.configure_package-name"></a>name |  The identity (i.e., name in the package's manifest) for the Swift package.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="swift_deps.configure_package-build_file"></a>build_file |  When used, the provided BUILD file will be used instead of generating one.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="swift_deps.configure_package-init_submodules"></a>init_submodules |  Whether to clone submodules in the repository.   | Boolean | optional |  `False`  |
| <a id="swift_deps.configure_package-patch_args"></a>patch_args |  The arguments given to the patch tool. Defaults to -p0, however -p1 will usually be needed for patches generated by git. If multiple -p arguments are specified, the last one will take effect.If arguments other than -p are specified, Bazel will fall back to use patch command line tool instead of the Bazel-native patch implementation. When falling back to patch command line tool and patch_tool attribute is not specified, `patch` will be used.   | List of strings | optional |  `["-p0"]`  |
| <a id="swift_deps.configure_package-patch_cmds"></a>patch_cmds |  Sequence of Bash commands to be applied on Linux/Macos after patches are applied.   | List of strings | optional |  `[]`  |
| <a id="swift_deps.configure_package-patch_cmds_win"></a>patch_cmds_win |  Sequence of Powershell commands to be applied on Windows after patches are applied. If this attribute is not set, patch_cmds will be executed on Windows, which requires Bash binary to exist.   | List of strings | optional |  `[]`  |
| <a id="swift_deps.configure_package-patch_tool"></a>patch_tool |  The patch(1) utility to use. If this is specified, Bazel will use the specified patch tool instead of the Bazel-native patch implementation.   | String | optional |  `""`  |
| <a id="swift_deps.configure_package-patches"></a>patches |  A list of files that are to be applied as patches after extracting the archive. By default, it uses the Bazel-native patch implementation which doesn't support fuzz match and binary patch, but Bazel will fall back to use patch command line tool if `patch_tool` attribute is specified or there are arguments other than `-p` in `patch_args` attribute.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="swift_deps.configure_package-publicly_expose_all_targets"></a>publicly_expose_all_targets |  Allows to expose internal build targets required for package compilation. The structure and labels of exposed targets may change in future releases without requiring a major version bump.   | Boolean | optional |  `False`  |
| <a id="swift_deps.configure_package-recursive_init_submodules"></a>recursive_init_submodules |  Whether to clone submodules recursively in the repository.   | Boolean | optional |  `True`  |
| <a id="swift_deps.configure_package-target_deps"></a>target_deps |  Additional dependencies to add to generated targets for this package.<br><br>Keys are Swift package target names, such as `ExampleTarget`, which are mapped to generated implementation target names such as `ExampleTarget.rspm.__impl`. If the key already contains `.rspm`, it is matched as a generated target name unchanged. Values may be Bazel label strings or Swift package target names. Bare value strings and local label strings such as `OtherTarget` or `:OtherTarget` are mapped to generated target labels such as `:OtherTarget.rspm` when they match Swift package targets in the same generated BUILD package. Values that contain `.rspm`, external labels, cross-package labels, and local labels that do not match package targets are emitted unchanged.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> List of strings</a> | optional |  `{}`  |

<a id="swift_deps.configure_swift_package"></a>

### configure_swift_package

Used to configure the flags used when running the `swift package` binary.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.configure_swift_package-build_path"></a>build_path |  The relative path within the runfiles tree for the Swift Package Manager build directory.   | String | optional |  `".build"`  |
| <a id="swift_deps.configure_swift_package-cache_path"></a>cache_path |  The relative path within the runfiles tree for the shared Swift Package Manager cache directory.   | String | optional |  `".cache"`  |
| <a id="swift_deps.configure_swift_package-config_path"></a>config_path |  The relative path within the runfiles tree for the Swift Package Manager configuration directory.   | String | optional |  `".config"`  |
| <a id="swift_deps.configure_swift_package-dependency_caching"></a>dependency_caching |  Whether to enable the dependency cache.   | Boolean | optional |  `True`  |
| <a id="swift_deps.configure_swift_package-manifest_cache"></a>manifest_cache |  Caching mode of Package.swift manifests (shared: shared cache, local: package's build directory, none: disabled)   | String | optional |  `"shared"`  |
| <a id="swift_deps.configure_swift_package-manifest_caching"></a>manifest_caching |  Whether to enable build manifest caching.   | Boolean | optional |  `True`  |
| <a id="swift_deps.configure_swift_package-replace_scm_with_registry"></a>replace_scm_with_registry |  Look up source control dependencies in the registry and use the registry to retrieve them instead of source control when possible.   | Boolean | optional |  `False`  |
| <a id="swift_deps.configure_swift_package-security_path"></a>security_path |  The relative path within the runfiles tree for the security directory.   | String | optional |  `".security"`  |
| <a id="swift_deps.configure_swift_package-use_registry_identity_for_scm"></a>use_registry_identity_for_scm |  Look up source control dependencies in the registry and use their registry identity when possible to help deduplicate across the two origins.   | Boolean | optional |  `False`  |

<a id="swift_deps.from_package"></a>

### from_package

Load Swift packages from `Package.swift` and `Package.resolved` files.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="swift_deps.from_package-cached_json_directory"></a>cached_json_directory |  -   | String | optional |  `""`  |
| <a id="swift_deps.from_package-declare_swift_deps_info"></a>declare_swift_deps_info |  Declare a `swift_deps_info` repository that is used by external tooling (e.g. Swift Gazelle plugin).   | Boolean | optional |  `False`  |
| <a id="swift_deps.from_package-declare_swift_package"></a>declare_swift_package |  Declare a `swift_package_tool` repository named `swift_package` which defines two targets: `update` and `resolve`. These targets run can be used to run the `swift package` binary in a Bazel context. The flags used when running the underlying `swift package` can be configured using the `configure_swift_package` tag.<br><br>They can be `bazel run` to update/resolve the `resolved` file:<br><br><pre><code>bazel run @swift_package//:update&#10;bazel run @swift_package//:resolve</code></pre>   | Boolean | optional |  `True`  |
| <a id="swift_deps.from_package-env"></a>env |  Environment variables that will be passed to the execution environments for this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM package description generation)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="swift_deps.from_package-env_inherit"></a>env_inherit |  Environment variables to inherit from the external environment that will be passed to the execution environments for this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM package description generation)   | List of strings | optional |  `[]`  |
| <a id="swift_deps.from_package-netrc"></a>netrc |  A `.netrc` file that contains authentication credentials used for fetching Swift packages and or binary artifacts.<br><br>When provided, this file will be passed to Swift Package Manager commands using the `--netrc-file` flag during package resolution and updates.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="swift_deps.from_package-registries"></a>registries |  A `registries.json` file that defines the configured Swift package registries.<br><br>The `registries.json` file is used when resolving Swift packages from a Swift package registry. It is created by Swift Package Manager when using the `swift package-registry` commands.<br><br>When using the `swift_package_tool` rules, this file is symlinked to the `config_path` directory defined in the `configure_swift_package` tag. If not using the `swift_package_tool` rules, the file must be in one of Swift Package Manager's search paths or in the manually specified `--config-path` directory.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="swift_deps.from_package-resolve_transitive_local_dependencies"></a>resolve_transitive_local_dependencies |  Local Swift packages that are declared directly in the `Package.swift` file can depend on other local packages. By default these transitive dependencies will be automatically resolved and made available during the build process.<br><br>The process of resolving transitive local dependencies can become time consuming as the number of local Swift packages grows. Setting this flag to `False` will skip resolving local packages and instead require every local Swift package that is required during the build to be explicitly defined in the `Package.swift` file.<br><br>This time appears as `Fetching module extension swift_deps in @@rules_swift_package_manager~//:extensions.bzl;` in the output log.   | Boolean | optional |  `True`  |
| <a id="swift_deps.from_package-resolved"></a>resolved |  A `Package.resolved`.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="swift_deps.from_package-swift"></a>swift |  A `Package.swift`.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


