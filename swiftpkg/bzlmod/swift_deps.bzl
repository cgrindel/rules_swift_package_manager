"""Implementation for `swift_deps` bzlmod extension."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//swiftpkg/internal:bazel_target_mods.bzl", "bazel_target_mods")
load("//swiftpkg/internal:swift_package.bzl", "PATCH_ATTRS", "TOOL_ATTRS")
load("//swiftpkg/internal:swift_package_tool_attrs.bzl", "swift_package_tool_attrs")
load(":slice_declarations.bzl", "slice_declarations")
load(":swift_deps_common.bzl", "INFERENCE_KEYS", "swift_deps_common")

# MARK: - swift_deps bzlmod Extension

def _non_root_target_mods_error(module_name, tag_groups):
    """Check that a non-root module did not declare target modification tags.

    Args:
        module_name: The name of the Bazel module as a `string`.
        tag_groups: A `list` of `struct` values with a `tag_class` `string`, a
            `verb` `string` and a `tags` `list`.

    Returns:
        A `string` describing the problem, or `None` if there is none.
    """
    declared = [tg.tag_class for tg in tag_groups if tg.tags]
    if not declared:
        return None
    return """\
Only the root module may declare `swift_deps` target modification tags, but \
module '{name}' declared: {declared}. Ask the maintainers of '{name}' to \
provide the setting a different way, or apply the modification from your root \
`MODULE.bazel`.\
""".format(
        declared = ", ".join(declared),
        name = module_name,
    )

# The `select()` branch value types that are declared as `string` values and
# converted to their Starlark type by this extension.
_BOOL_BRANCH = "bool"
_INT_BRANCH = "int"

_VERBS = bazel_target_mods.verbs

# Every target modification tag class, mapped to the `bazel_target_mods` verb
# that it declares. The tag class states the type of the value, so nothing is
# parsed or guessed. `branch_type` is set for the two `select()` tag classes
# whose branch values arrive as `string` values that must be converted.
_BAZEL_TARGET_MOD_TAG_SPECS = [
    struct(tag_class = "bazel_target_set_bool", verb = _VERBS.set, branch_type = None),
    struct(tag_class = "bazel_target_set_int", verb = _VERBS.set, branch_type = None),
    struct(tag_class = "bazel_target_set_string", verb = _VERBS.set, branch_type = None),
    struct(
        tag_class = "bazel_target_set_string_list",
        verb = _VERBS.set,
        branch_type = None,
    ),
    struct(
        tag_class = "bazel_target_set_string_dict",
        verb = _VERBS.set,
        branch_type = None,
    ),
    struct(
        tag_class = "bazel_target_set_select_bool_dict",
        verb = _VERBS.set_select,
        branch_type = _BOOL_BRANCH,
    ),
    struct(
        tag_class = "bazel_target_set_select_int_dict",
        verb = _VERBS.set_select,
        branch_type = _INT_BRANCH,
    ),
    struct(
        tag_class = "bazel_target_set_select_string_dict",
        verb = _VERBS.set_select,
        branch_type = None,
    ),
    struct(
        tag_class = "bazel_target_set_select_string_list_dict",
        verb = _VERBS.set_select,
        branch_type = None,
    ),
    struct(tag_class = "bazel_target_add", verb = _VERBS.add, branch_type = None),
    struct(
        tag_class = "bazel_target_add_select",
        verb = _VERBS.add_select,
        branch_type = None,
    ),
]

def _bool_branch_value(value):
    """Convert a `select()` branch value `string` to a `bool`.

    Args:
        value: The branch value as a `string`.

    Returns:
        A `bool` for `True` or `False`, spelled exactly as Starlark spells them.
        Otherwise, `None`.
    """
    if value == "True":
        return True
    if value == "False":
        return False
    return None

def _int_branch_value(value):
    """Convert a `select()` branch value `string` to an `int`.

    Args:
        value: The branch value as a `string`.

    Returns:
        An `int` for an all-digit value with an optional leading `-`. Otherwise,
        `None`.
    """
    digits = value[1:] if value.startswith("-") else value
    if digits == "" or not digits.isdigit():
        return None
    return int(value)

def _branch_values(tag_class, branch_type, tag):
    """Convert the `select()` branch values of a tag to their Starlark type.

    Args:
        tag_class: The name of the tag class as a `string`.
        branch_type: `bool` or `int` as a `string`.
        tag: The modification tag.

    Returns:
        A `struct` with a `values` `dict` mapping `select()` conditions to
        `bool` or `int` values and an `error` `string`. The `error` is `None`
        when every branch value was converted; otherwise, it describes the
        problem and `values` is `None`.
    """
    if branch_type == _BOOL_BRANCH:
        expected = "exactly `True` or `False`"
    else:
        expected = "an integer (digits with an optional leading `-`)"
    values = {}
    for (condition, value) in tag.values.items():
        if branch_type == _BOOL_BRANCH:
            converted = _bool_branch_value(value)
        else:
            converted = _int_branch_value(value)
        if converted == None:
            return struct(
                values = None,
                error = """\
The `{tag_class}` tag for '{target}' attribute '{attr}' has an invalid value \
for condition '{condition}': '{value}'. Values must be {expected}.\
""".format(
                    attr = tag.attr,
                    condition = condition,
                    expected = expected,
                    tag_class = tag_class,
                    target = tag.target,
                    value = value,
                ),
            )
        values[condition] = converted
    return struct(values = values, error = None)

def _converted_tag(tag_class, branch_type, tag):
    """Convert a `select()` tag's branch values to their Starlark type.

    Args:
        tag_class: The name of the tag class as a `string`.
        branch_type: `bool` or `int` as a `string`.
        tag: The modification tag.

    Returns:
        A `struct` with the tag's `attr`, `target` and converted `values`.
    """
    result = _branch_values(tag_class, branch_type, tag)
    if result.error != None:
        fail(result.error)
    return struct(attr = tag.attr, target = tag.target, values = result.values)

def _bazel_target_mod_tag_groups(mod, convert):
    """Collect the target modification tags declared by a Bazel module.

    Args:
        mod: A Bazel module as provided by `module_ctx.modules`.
        convert: A `bool` specifying whether the `select()` branch values that
            arrive as `string` values should be converted to their Starlark
            type. Conversion fails on a malformed value, so it is skipped for
            the modules that are rejected for declaring these tags at all.

    Returns:
        A `list` of `struct` values with a `tag_class` `string`, a `verb`
        `string` and a `tags` `list`.
    """
    tag_groups = []
    for spec in _BAZEL_TARGET_MOD_TAG_SPECS:
        tags = getattr(mod.tags, spec.tag_class)
        if convert and spec.branch_type != None:
            tags = [
                _converted_tag(spec.tag_class, spec.branch_type, tag)
                for tag in tags
            ]
        tag_groups.append(struct(
            tag_class = spec.tag_class,
            tags = tags,
            verb = spec.verb,
        ))
    return tag_groups

def _bazel_target_mods_by_repo(module_ctx):
    """Collect the buildozer-style target modifications from the root module.

    Args:
        module_ctx: An instance of `module_ctx`.

    Returns:
        A `dict` mapping a generated repository name to a `list` of
        modification `dict` values as returned by `bazel_target_mods.new`.
    """
    tag_groups = []
    for mod in module_ctx.modules:
        if not mod.is_root:
            error = _non_root_target_mods_error(
                mod.name,
                _bazel_target_mod_tag_groups(mod, convert = False),
            )
            if error != None:
                fail(error)
            continue
        tag_groups.extend(_bazel_target_mod_tag_groups(mod, convert = True))

    return bazel_target_mods.mods_by_repo(tag_groups)

def _inference_configuration(modules):
    defaults = {key: False for key in INFERENCE_KEYS}
    packages = {}
    root_package_names = {}
    configured = False
    for mod in modules:
        tags = mod.tags.configure_explicit_modules
        if tags and not mod.is_root:
            return struct(error = """\
Only the root module may declare configure_explicit_modules \
(found in '{}').\
""".format(mod.name))
        for tag in tags:
            if configured:
                return struct(error = """\
Expected at most one configure_explicit_modules tag in the root module.\
""")
            configured = True
            defaults = {key: getattr(tag, key) for key in INFERENCE_KEYS}
        for tag in mod.tags.configure_package:
            overrides = {key: getattr(tag, key) for key in INFERENCE_KEYS}
            if not mod.is_root:
                if any([value != "inherit" for value in overrides.values()]):
                    return struct(error = """\
Only the root module may override dependency inference for package '{}' \
(found in '{}').\
""".format(tag.name, mod.name))
                continue
            if tag.name in root_package_names:
                return struct(error = """\
Duplicate configure_package tags in the root module for '{}'. Put all \
settings for this package in one tag so existing settings are not lost.\
""".format(tag.name))
            root_package_names[tag.name] = True
            if all([value == "inherit" for value in overrides.values()]):
                continue
            packages[tag.name] = overrides
    return struct(
        error = None,
        defaults = defaults,
        packages = packages,
        matched_names = {},
        available_names = {},
    )

def _unknown_inference_packages_error(config):
    unknown = sorted([
        name
        for name in config.packages
        if name not in config.matched_names
    ])
    if not unknown:
        return None
    return """\
Dependency inference overrides were declared for unknown packages: {unknown}. \
Available package names and repositories are: {available}.\
""".format(
        unknown = ", ".join(unknown),
        available = ", ".join(sorted(config.available_names)),
    )

def _extension_metadata(
        module_ctx,
        direct_dep_repo_names,
        direct_dev_dep_repo_names):
    """Create the extension metadata for the root module's direct deps.

    A repository that is both a dev and a non-dev dependency is reported only
    as a non-dev dependency.

    Args:
        module_ctx: A `module_ctx`.
        direct_dep_repo_names: A `list` of the repository names declared by
            the root module's non-dev `from_package` tags.
        direct_dev_dep_repo_names: A `list` of the repository names declared
            by the root module's dev `from_package` tags.

    Returns:
        The `extension_metadata` for the extension.
    """
    direct_deps = {name: None for name in direct_dep_repo_names}
    direct_dev_deps = {
        name: None
        for name in direct_dev_dep_repo_names
        if name not in direct_deps
    }
    return module_ctx.extension_metadata(
        root_module_direct_deps = list(direct_deps),
        root_module_direct_dev_deps = list(direct_dev_deps),
    )

def _swift_deps_impl(module_ctx):
    """Implementation for the `swift_deps` module extension.

    Every `from_package` tag describes one slice. The slices' cached manifests
    are read here and by the package repositories; nothing runs Swift Package
    Manager while Bazel loads.

    Args:
        module_ctx: An instance of `module_ctx`.

    Returns:
        The extension metadata from `module_ctx.extension_metadata`.
    """
    inference_config = _inference_configuration(module_ctx.modules)
    if inference_config.error:
        fail(inference_config.error)
    config_pkgs = {}
    for mod in module_ctx.modules:
        for config_pkg in mod.tags.configure_package:
            config_pkgs[config_pkg.name] = config_pkg
    config_swift_package = None
    for mod in module_ctx.modules:
        for config_swift_package_tag in mod.tags.configure_swift_package:
            if config_swift_package:
                fail("""\
Expected only one `configure_swift_package` tag, but found multiple.\
""")
            config_swift_package = config_swift_package_tag

    target_mods_by_repo = _bazel_target_mods_by_repo(module_ctx)
    matched_target_mod_repos = {}
    available_target_mod_repos = {}
    direct_dep_repo_names = []
    direct_dev_dep_repo_names = []
    all_slices = slice_declarations.collect(module_ctx)
    if all_slices:
        evaluated = [
            slice_declarations.evaluate(
                module_ctx,
                slice,
                config_swift_package,
                config_pkgs,
            )
            for slice in all_slices
        ]
        repo_names = slice_declarations.declare(
            module_ctx,
            evaluated,
            config_pkgs,
            config_swift_package,
            target_mods_by_repo,
            matched_target_mod_repos,
            available_target_mod_repos,
            inference_config,
        )
        direct_dep_repo_names.extend(repo_names.direct)
        direct_dev_dep_repo_names.extend(repo_names.direct_dev)

    inference_error = _unknown_inference_packages_error(inference_config)
    if inference_error:
        fail(inference_error)

    unknown_target_mod_repos = [
        repo_name
        for repo_name in target_mods_by_repo
        if repo_name not in matched_target_mod_repos
    ]
    if unknown_target_mod_repos:
        fail("""\
Target modifications were declared for unknown repositories: {unknown}. \
Available repositories are: {available}.\
""".format(
            available = ", ".join(sorted(available_target_mod_repos.keys())),
            unknown = ", ".join(sorted(unknown_target_mod_repos)),
        ))
    return _extension_metadata(
        module_ctx,
        direct_dep_repo_names,
        direct_dev_dep_repo_names,
    )

_from_package_tag = tag_class(
    attrs = dicts.add(
        swift_package_tool_attrs.swift_package_registry,
        {
            "config": attr.label(
                mandatory = True,
                doc = """\
The label that selects this slice, anything `select()` accepts (e.g. \
`@rules_swift_package_manager//config:any`). Each slice of the root module \
needs its own config. `configure_package` patches may only be files in the \
root module.\
""",
            ),
            "desc_manifests": attr.string_keyed_label_dict(
                mandatory = True,
                doc = """\
Maps a package identity (`_main` for the root package, e.g. `swift-log` for a \
dependency) to its checked-in `swift package describe` manifest for this \
slice. `init` writes an empty `dict`; the `cache` command fills it.\
""",
            ),
            "dump_manifests": attr.string_keyed_label_dict(
                mandatory = True,
                doc = """\
Maps a package identity (`_main` for the root package, e.g. `swift-log` for a \
dependency) to its checked-in `swift package dump-package` manifest for this \
slice. Declare one `from_package` tag per slice; the slice directory is the \
Bazel package of `resolved`. `init` writes an empty `dict`; the `cache` \
command fills it.\
""",
            ),
            "make_files_read_only": attr.bool(
                default = False,
                doc = """\
Whether to make files in fetched Swift packages read-only. This helps prevent \
accidental edits when external repositories are exposed by tools such as \
`rules_xcodeproj`.\
""",
            ),
            "resolved": attr.label(
                mandatory = True,
                allow_files = [".resolved"],
                doc = "The slice's `Package.resolved`. Its package is the slice directory.",
            ),
            "swift": attr.label(
                mandatory = True,
                allow_files = [".swift"],
                doc = "A `Package.swift`.",
            ),
        },
    ),
    doc = """\
Declares one slice: one resolution of `Package.swift` for one config, with \
the manifests that the `cache` command checked in. Only the root module may \
declare this tag for now.\
""",
)

_configure_explicit_modules_tag = tag_class(
    attrs = {
        key: attr.bool(
            default = False,
            doc = """\
Opt in to {} inference. Reserved configuration: inference is not implemented yet.\
""".format(
                "SDK dependency" if key == "system_sdk_deps" else "binary-target dependency",
            ),
        )
        for key in INFERENCE_KEYS
    },
    doc = """\
Root-only defaults for independent dependency inference settings. Does not \
enable compiler features or generate inferred dependencies yet.\
""",
)

_inference_override_attrs = {
    key: attr.string(
        default = "inherit",
        values = ["inherit", "on", "off"],
        doc = """\
Root-only package override for {}: inherit the global default, enable, or \
disable. Inference is not implemented yet.\
""".format(key),
    )
    for key in INFERENCE_KEYS
}

_configure_package_tag = tag_class(
    attrs = {
        "init_submodules": attr.bool(
            default = False,
            doc = "Whether to clone submodules in the repository.",
        ),
        "name": attr.string(
            doc = """\
The identity (i.e., name in the package's manifest) for the Swift package.\
""",
            mandatory = True,
        ),
        "recursive_init_submodules": attr.bool(
            default = True,
            doc = "Whether to clone submodules recursively in the repository.",
        ),
        "target_deps": attr.string_list_dict(
            doc = """\
Additional dependencies to add to generated targets for this package.

Keys are Swift package target names, such as `ExampleTarget`, which are mapped \
to generated implementation target names such as `ExampleTarget.rspm.__impl`. \
If the key already contains `.rspm`, it is matched as a generated target name \
unchanged. Values may be Bazel label strings or Swift package target names. \
Bare value strings and local label strings such as `OtherTarget` or \
`:OtherTarget` are mapped to generated target labels such as \
`:OtherTarget.rspm` when they match Swift package targets in the same \
generated BUILD package. Values that contain `.rspm`, external labels, \
cross-package labels, and local labels that do not match package targets are \
emitted unchanged.\
""",
        ),
    } | PATCH_ATTRS | TOOL_ATTRS | _inference_override_attrs,
    doc = "Used to add or override settings for a particular Swift package.",
)

_configure_swift_package_tag = tag_class(
    attrs = swift_package_tool_attrs.swift_package_tool_config,
    doc = "Used to configure the flags used when running the `swift package` binary.",
)

_BAZEL_TARGET_MOD_DOC_SUFFIX = """\

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule \
does not understand fails when Bazel loads the generated `BUILD.bazel` file, \
with Bazel's own error message. Use at your own risk.\
"""

_bazel_target_attr = attr.string(
    doc = """\
The name of the attribute to modify, such as `copts`. The `name` attribute may \
not be modified.\
""",
    mandatory = True,
)

_bazel_target_target_attr = attr.string(
    doc = """\
A `string` naming a declaration in a generated repository, such as \
`@swiftpkg_foo//:Bar.rspm.__impl`. It looks like a label, but it is not \
resolved as one. The repository portion is the name of the generated \
repository as this ruleset named it (e.g. `swiftpkg_foo`), not an alias \
declared with `use_repo` and not Bazel's canonical repository name, so the \
`@@` prefix is rejected. Every generated declaration lives in the root \
package of its repository, so the value must be of the form \
`@repo_name//:target_name`.\
""",
    mandatory = True,
)

_VERBATIM_VALUE_DOC = """\
The value is written into the generated `BUILD.bazel` file verbatim. Label \
values are not remapped, so a value such as `//:my_lib` resolves inside the \
generated repository, not your root module. Use `@@//:my_lib` to name a target \
in the main repository.\
"""

_VERBATIM_VALUES_DOC = """\
The values are written into the generated `BUILD.bazel` file verbatim. Label \
values are not remapped, so a value such as `//:my_lib` resolves inside the \
generated repository, not your root module. Use `@@//:my_lib` to name a target \
in the main repository.\
"""

_SELECT_KEYS_DOC = """\
Keys are absolute condition labels; a key that is relative to the main \
repository (e.g. `//:release_build`) is canonicalized (e.g. \
`@@//:release_build`) so that it still resolves from inside the generated \
repository. A key that names an apparent repository (a single `@`, e.g. \
`@some_repo//:setting`) is rejected, because it would be resolved against the \
generated repository's repository mapping; use a canonical label (e.g. \
`@@some_repo+//:setting`) instead.\
"""

_SET_SELECT_DEFAULT_DOC = """\
No `//conditions:default` branch is added for you.\
"""

_SET_SELECT_DOC = """\
Replace (or create) an attribute on a generated declaration with a `select()`.
""" + _BAZEL_TARGET_MOD_DOC_SUFFIX

def _bazel_target_set_tag_class(value_attr):
    """Create a tag class that replaces an attribute with a typed value.

    Args:
        value_attr: The `attr` for the `value` attribute.

    Returns:
        A `tag_class`.
    """
    return tag_class(
        attrs = {
            "attr": _bazel_target_attr,
            "target": _bazel_target_target_attr,
            "value": value_attr,
        },
        doc = """\
Replace (or create) an attribute on a generated declaration.
""" + _BAZEL_TARGET_MOD_DOC_SUFFIX,
    )

def _bazel_target_set_select_tag_class(values_attr):
    """Create a tag class that replaces an attribute with a `select()`.

    Args:
        values_attr: The `attr` for the `values` attribute.

    Returns:
        A `tag_class`.
    """
    return tag_class(
        attrs = {
            "attr": _bazel_target_attr,
            "target": _bazel_target_target_attr,
            "values": values_attr,
        },
        doc = _SET_SELECT_DOC,
    )

_bazel_target_set_bool_tag = _bazel_target_set_tag_class(
    attr.bool(
        doc = """\
The replacement value as a `bool`.\
""",
        mandatory = True,
    ),
)

_bazel_target_set_int_tag = _bazel_target_set_tag_class(
    attr.int(
        doc = """\
The replacement value as an `int`.\
""",
        mandatory = True,
    ),
)

_bazel_target_set_string_tag = _bazel_target_set_tag_class(
    attr.string(
        doc = """\
The replacement value as a `string`. An empty `string` is allowed.

""" + _VERBATIM_VALUE_DOC,
        mandatory = True,
    ),
)

_bazel_target_set_string_list_tag = _bazel_target_set_tag_class(
    attr.string_list(
        doc = """\
The replacement value as a `list` of `string` values. An empty `list` is \
allowed and clears the attribute.

""" + _VERBATIM_VALUES_DOC,
        mandatory = True,
    ),
)

_bazel_target_set_string_dict_tag = _bazel_target_set_tag_class(
    attr.string_dict(
        doc = """\
The replacement value as a `dict` of `string` keys to `string` values. An \
empty `dict` is allowed and clears the attribute.

""" + _VERBATIM_VALUES_DOC,
        mandatory = True,
    ),
)

_bazel_target_add_tag = tag_class(
    attrs = {
        "attr": _bazel_target_attr,
        "target": _bazel_target_target_attr,
        "values": attr.string_list(
            doc = """\
The values to append. At least one value is required. If the attribute is \
absent, it is created with these values.

""" + _VERBATIM_VALUES_DOC,
            mandatory = True,
        ),
    },
    doc = """\
Append values to a list attribute on a generated declaration.

The values are appended after the generated values, so options that follow \
last-option-wins semantics (e.g. `copts`) override the generated ones.
""" + _BAZEL_TARGET_MOD_DOC_SUFFIX,
)

_bazel_target_set_select_string_dict_tag = _bazel_target_set_select_tag_class(
    attr.string_dict(
        doc = """\
The `select()` branches, whose values are `string` values. \
""" + _SELECT_KEYS_DOC + " " + _SET_SELECT_DEFAULT_DOC + """
""" + _VERBATIM_VALUES_DOC,
        mandatory = True,
    ),
)

_bazel_target_set_select_string_list_dict_tag = _bazel_target_set_select_tag_class(
    attr.string_list_dict(
        doc = """\
The `select()` branches, whose values are `list` values of `string` values. \
""" + _SELECT_KEYS_DOC + " " + _SET_SELECT_DEFAULT_DOC + """
""" + _VERBATIM_VALUES_DOC,
        mandatory = True,
    ),
)

_bazel_target_set_select_bool_dict_tag = _bazel_target_set_select_tag_class(
    attr.string_dict(
        doc = """\
The `select()` branches, whose values are `string` values that are converted \
to a `bool`. Each value must be exactly `True` or `False`, spelled the way \
Starlark spells them; any other value fails when the module extension is \
evaluated. \
""" + _SELECT_KEYS_DOC + " " + _SET_SELECT_DEFAULT_DOC,
        mandatory = True,
    ),
)

_bazel_target_set_select_int_dict_tag = _bazel_target_set_select_tag_class(
    attr.string_dict(
        doc = """\
The `select()` branches, whose values are `string` values that are converted \
to an `int`. Each value must be digits with an optional leading `-`; any other \
value fails when the module extension is evaluated. \
""" + _SELECT_KEYS_DOC + " " + _SET_SELECT_DEFAULT_DOC,
        mandatory = True,
    ),
)

_bazel_target_add_select_tag = tag_class(
    attrs = {
        "attr": _bazel_target_attr,
        "target": _bazel_target_target_attr,
        "values": attr.string_list_dict(
            doc = """\
The `select()` branches, whose values are `list` values of `string` values. \
""" + _SELECT_KEYS_DOC + """ A `//conditions:default` branch with no values is \
added when one is not provided.

""" + _VERBATIM_VALUES_DOC,
            mandatory = True,
        ),
    },
    doc = """\
Append a `select()` to an attribute on a generated declaration.

The generated value is preserved: the attribute renders as \
`<generated> + select({...})`.
""" + _BAZEL_TARGET_MOD_DOC_SUFFIX,
)

swift_deps = module_extension(
    implementation = _swift_deps_impl,
    tag_classes = {
        "bazel_target_add": _bazel_target_add_tag,
        "bazel_target_add_select": _bazel_target_add_select_tag,
        "bazel_target_set_bool": _bazel_target_set_bool_tag,
        "bazel_target_set_int": _bazel_target_set_int_tag,
        "bazel_target_set_select_bool_dict": _bazel_target_set_select_bool_dict_tag,
        "bazel_target_set_select_int_dict": _bazel_target_set_select_int_dict_tag,
        "bazel_target_set_select_string_dict": _bazel_target_set_select_string_dict_tag,
        "bazel_target_set_select_string_list_dict": _bazel_target_set_select_string_list_dict_tag,
        "bazel_target_set_string": _bazel_target_set_string_tag,
        "bazel_target_set_string_dict": _bazel_target_set_string_dict_tag,
        "bazel_target_set_string_list": _bazel_target_set_string_list_tag,
        "configure_explicit_modules": _configure_explicit_modules_tag,
        "configure_package": _configure_package_tag,
        "configure_swift_package": _configure_swift_package_tag,
        "from_package": _from_package_tag,
    },
)

swift_deps_test_utils = struct(
    extension_metadata = _extension_metadata,
    inference_configuration = _inference_configuration,
    inference_settings = swift_deps_common.inference_settings,
    record_inference_packages = swift_deps_common.record_inference_packages,
    unknown_inference_packages_error = _unknown_inference_packages_error,
    branch_values = _branch_values,
    bazel_target_mod_tag_classes = [
        spec.tag_class
        for spec in _BAZEL_TARGET_MOD_TAG_SPECS
    ],
    bazel_target_mods_by_repo = _bazel_target_mods_by_repo,
    build_file_conflict_error = swift_deps_common.build_file_conflict_error,
    non_root_target_mods_error = _non_root_target_mods_error,
)
