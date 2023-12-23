"""\
Module for transforming Swift package manifest conditionals to Bazel select \
statements.\
"""

load("@bazel_skylib//lib:sets.bzl", "sets")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")
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

def _new_from_build_setting(build_setting, values_map_fn = None):
    """Create conditions from an SPM build setting.

    Args:
        build_setting: A `struct` as returned by `pkginfos.new_build_setting`.
        values_map_fn: Optional. A `function` that is applied to each value
            before being added to condition struct.

    Returns:
        A `list` of condition `struct` values (`bzl_selects.new`).
    """
    if values_map_fn == None:
        values = build_setting.values
    else:
        values = lists.map(build_setting.values, values_map_fn)

    bsc = build_setting.condition
    if bsc == None:
        return [
            _new(kind = build_setting.kind, value = v)
            for v in values
        ]

    supported_platforms = spm_platforms.supported(bsc.platforms)
    platforms_len = len(supported_platforms)
    if platforms_len > 0 and bsc.configuration != None:
        conditions = [
            spm_platform_configurations.label(p, bsc.configuration)
            for p in supported_platforms
        ]
    elif platforms_len > 0:
        conditions = [spm_platforms.label(p) for p in supported_platforms]
    elif bsc.configuration != None:
        conditions = [spm_configurations.label(bsc.configuration)]
    else:
        return []

    # platforms_len = len(bsc.platforms)
    # if platforms_len > 0 and bsc.configuration != None:
    #     conditions = [
    #         spm_platform_configurations.label(p, bsc.configuration)
    #         for p in bsc.platforms
    #     ]
    # elif platforms_len > 0:
    #     conditions = [spm_platforms.label(p) for p in bsc.platforms]
    # elif bsc.configuration != None:
    #     conditions = [spm_configurations.label(bsc.configuration)]
    # else:
    #     fail("""\
    # Found a build setting condition that had no platforms or a configuration. {}\
    # """.format(build_setting))

    return [
        _new(kind = build_setting.kind, value = v, condition = c)
        for v in values
        for c in conditions
    ]

def _new_from_target_dependency_condition(kind, labels, condition = None):
    """Create conditions from an SPM target dependency condition.

    Args:
        kind: A `string` that identifies how to group the conditions.
        labels: A `list` of Bazel label `string` values.
        condition: Optional. A `struct` as returned by
            `pkginfos.new_target_dependency_condition`.

    Returns:
        A `list` of `struct` values as returned by `bzl_selects.new`.
    """
    if condition == None:
        return [_new(kind = kind, value = labels)]

    conditions = [
        spm_platforms.label(p)
        for p in spm_platforms.supported(condition.platforms)
    ]

    # platforms_len = len(condition.platforms)
    # if platforms_len > 0:
    #     conditions = [spm_platforms.label(p) for p in condition.platforms]
    # else:
    #     fail("""\
    # Found a target dependency condition that had no platforms. {}\
    # """.format(condition))
    return [
        _new(kind = kind, value = labels, condition = c)
        for c in conditions
    ]

def _new_kind_handler(transform = None, default = []):
    """Creates a struct that encapsulates the information needed to process a \
    condition.

    Args:
        transform: Optional. A `function` that accepts a single value. The value for a
            condition is passed this function. The return value is used as the
            Starlark output.
        default: Optional. The value that should be added to the `select` dict
            for the kind. Defaults to `[]`.

    Returns:
        A `struct` representing the information needed to process and kind
        condition.
    """
    if transform == None:
        transform = lambda v: v
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
        values: A `list` of values that are processed and added to the output.
        kind_handlers: A `dict` of king handler `struct` values
            (`bzl_selects.new_kind_handler`).

    Returns:
        A `struct` as returned by `starlark_codegen.new_expr`.
    """
    if len(values) == 0:
        return scg.new_expr([])

    # The selects_by_kind has keys which are the kind and the value is a select
    # dict whose keys are the conditions and the value is the value for the
    # condition.
    selects_by_kind = {}
    no_condition_results = sets.make()

    for v in values:
        v_type = type(v)
        if v_type != "struct":
            if v_type == "list":
                no_condition_results = sets.union(no_condition_results, sets.make(v))
            else:
                sets.insert(no_condition_results, v)
            continue

        # We are assuming that the select will always result in a list.
        # Hence, we wrap the transformed value in a list.
        kind_handler = kind_handlers.get(v.kind, _noop_kind_handler)
        tvs_set = sets.make(lists.flatten(kind_handler.transform(v.value)))
        if v.condition != None:
            # Collect all of the values associted with a condition.
            select_dict = selects_by_kind.get(v.kind, {})
            condition_values = select_dict.get(v.condition, sets.make())
            condition_values = sets.union(condition_values, tvs_set)
            select_dict[v.condition] = condition_values
            selects_by_kind[v.kind] = select_dict
        else:
            no_condition_results = sets.union(no_condition_results, tvs_set)

    expr_members = []
    if sets.length(no_condition_results) > 0:
        expr_members.append(sets.to_list(no_condition_results))
    for (kind, select_dict) in selects_by_kind.items():
        if len(expr_members) > 0:
            expr_members.append(scg.new_op("+"))
        sorted_keys = sorted(select_dict.keys())
        new_select_dict = {
            k: sets.to_list(select_dict[k])
            for k in sorted_keys
        }
        kind_handler = kind_handlers.get(kind, _noop_kind_handler)
        if kind_handler.default != None:
            new_select_dict[_bazel_select_default_condition] = kind_handler.default
        select_fn = scg.new_fn_call("select", new_select_dict)
        expr_members.append(select_fn)

    if len(expr_members) == 0:
        fail("""\
No Starlark expression members were generated for {}\
""".format(values))

    return scg.new_expr(*expr_members)

bzl_selects = struct(
    default_condition = _bazel_select_default_condition,
    new = _new,
    new_from_build_setting = _new_from_build_setting,
    new_from_target_dependency_condition = _new_from_target_dependency_condition,
    new_kind_handler = _new_kind_handler,
    to_starlark = _to_starlark,
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
#       "@rules_swift_package_manager//config_settings/platform_types:macos": ["-framework AppKit"],
#       "@rules_swift_package_manager//config_settings/platform_types:ios": ["-framework UIKit"],
#       "@rules_swift_package_manager//config_settings/platform_types:tvos": ["-framework UIKit"],
#       "//conditions:default": [],
#   })
