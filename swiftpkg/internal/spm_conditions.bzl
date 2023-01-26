"""
Module for transforming Swift package manifest conditionals to Starlark.
"""

load(
    "//config_settings/spm/configuration:configurations.bzl",
    spm_configurations = "configurations",
)
load(
    "//config_settings/spm/platform:platforms.bzl",
    spm_platforms = "platforms",
)
load(
    "//config_settings/spm/platform_configuration:platform_configurations.bzl",
    spm_platform_configurations = "platform_configurations",
)
load(":starlark_codegen.bzl", scg = "starlark_codegen")

_bazel_select_default_condition = "//conditions:default"

def _new(value, kind = None, condition = None):
    """Create `struct` that represents a Swift package manager condition.

    Args:
        value: The value associated with the condition.
        kind: Optional. A `string` that identifies the value. This comes from
            the SPM dump manifest. (e.g. `linkedFramework`)
        condition: Optional. A `string` representing a valid `select()` label.

    Returns:
        A `struct` representing a Swift package manager condition.
    """
    return struct(
        kind = kind,
        condition = condition,
        value = value,
    )

def _new_default(kind, value):
    """Create a condition with the condition set to Bazel's default value.

    Args:
        kind: A `string` that identifies the value. This comes from the SPM dump
            manifest. (e.g. `linkedFramework`)
        value: The value associated with the condition.

    Returns:
        A `struct` representing a Swift package manager condition.
    """
    return _new(
        kind = kind,
        condition = "//conditions:default",
        value = value,
    )

# GH153: Finish conditional support.

def _new_from_build_setting(build_setting):
    """Create conditions from an SPM build setting.

    Args:
        build_setting: A `struct` as returned by `pkginfos.new_build_setting`.

    Returns:
        A `list` of condition `struct` values (`spm_conditions.new`).
    """
    bsc = build_setting.condition
    if bsc == None:
        return [
            _new(kind = build_setting.kind, value = v)
            for v in build_setting.values
        ]

    if bsc.platforms != None and bsc.configuration != None:
        conditions = [
            spm_platform_configurations.label(p, bsc.configuration)
            for p in bsc.platforms
        ]
    elif bsc.platforms != None:
        conditions = [spm_platforms.label(p) for p in bsc.platforms]
    elif bsc.configuration != None:
        conditions = [spm_configurations.label(bsc.configuration)]
    else:
        fail("""\
Found a build setting condition that had no platforms or a configuration. {}\
""".format(build_setting))

    return [
        _new(kind = build_setting.kind, value = v, condition = c)
        for v in build_setting.values
        for c in conditions
    ]

def _new_kind_handler(transform, default = None):
    """Creates a struct that encapsulates the information needed to process a \
    condition.

    Args:
        transform: A `function` that accepts a single value. The value for a
            condition is passed this function. The return value is used as the
            Starlark output.
        default: Optional. The value that should be added to the `select` dict
            for the kind.

    Returns:
        A `struct` representing the information needed to process and kind
        condition.
    """
    return struct(
        transform = transform,
        default = default,
    )

_noop_kind_handler = _new_kind_handler(
    transform = lambda v: v,
)

def _to_starlark(values, kind_handlers = {}):
    """Converts the provied values into Starlark using the information in the \
    kind handlers.

    Args:
        values: A `list` of values that processed and added to the output.
        kind_handlers: A `dict` of king handler `struct` values
            (`spm_conditions.new_kind_handler`).

    Returns:
        A `struct` as returned by `starlark_codegen.new_expr`.
    """

    # The selects_by_kind has keys which are the kind and the value is a select
    # dict whose keys are the conditions and the value is the value for the
    # condition.
    selects_by_kind = {}
    no_condition_results = []
    for v in values:
        # If it is not a struct, then we assume it needs no further handling.
        if type(v) != "struct":
            no_condition_results.append(v)
            continue

        kind_handler = kind_handlers.get(v.kind, default = _noop_kind_handler)
        tv = kind_handler.transform(v.value)
        if v.condition != None:
            select_dict = selects_by_kind.get(v.kind, default = {})

            # We are assuming that the select will always result in a list.
            # Hence, we wrap the transformed value in a list.
            select_dict[v.condition] = [tv]

            # If a default was specified and we have not already added it. Do so.
            if kind_handler.default != None and \
               select_dict.get(_bazel_select_default_condition) == None:
                select_dict[_bazel_select_default_condition] = kind_handler.default

            # Save the select dict
            selects_by_kind[v.kind] = select_dict
        else:
            no_condition_results.append(tv)

    expr_members = []
    if len(no_condition_results) > 0:
        expr_members.append(no_condition_results)
    for (_, select_dict) in selects_by_kind.items():
        if len(expr_members) > 0:
            expr_members.append(scg.new_op("+"))
        select_fn = scg.new_fn_call("select", select_dict)
        expr_members.append(select_fn)

    return scg.new_expr(*expr_members)

spm_conditions = struct(
    new_kind_handler = _new_kind_handler,
    new = _new,
    new_default = _new_default,
    new_from_build_setting = _new_from_build_setting,
    to_starlark = _to_starlark,
    default_condition = _bazel_select_default_condition,
)

# NEED TO CONVERT:
#   {
#     "kind" : {
#       "linkedFramework" : {
#         "_0" : "Foo"
#       }
#     },
#     "tool" : "linker"
#   },
#   {
#     "condition" : {
#       "platformNames" : [
#         "ios",
#         "tvos"
#       ]
#     },
#     "kind" : {
#       "linkedFramework" : {
#         "_0" : "UIKit"
#       }
#     },
#     "tool" : "linker"
#   },
#   {
#     "condition" : {
#       "platformNames" : [
#         "macos"
#       ]
#     },
#     "kind" : {
#       "linkedFramework" : {
#         "_0" : "AppKit"
#       }
#     },
#     "tool" : "linker"
#   }
# TO:
#   ["-framework Foo"] + select({
#       "@cgrindel_swift_bazel//config_settings/platform_types:macos": ["-framework AppKit"],
#       "@cgrindel_swift_bazel//config_settings/platform_types:ios": ["-framework UIKit"],
#       "@cgrindel_swift_bazel//config_settings/platform_types:tvos": ["-framework UIKit"],
#       "//conditions:default": [],
#   })
