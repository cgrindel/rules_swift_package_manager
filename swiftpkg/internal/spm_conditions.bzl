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
    """Create an SPM condition with the condition set to Bazel's default value.

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
    bsc = build_setting.condition
    if bsc == None:
        return [
            _new(kind = build_setting.kind, value = build_setting.values),
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

# def _build_settings_to_starlark(build_settings_or_strs):
#     members = []
#     no_conditions = []
#     with_conditions = []
#     for bs_or_str in build_settings_or_strs:
#         if type(bs_or_str) == "struct":
#             bs = bs_or_str
#             if bs.condition == None:
#                 no_conditions.extend(bs.value)
#             else:
#                 with_conditions.append(bs)
#         else:
#             no_conditions.append(bs_or_str)
#     if len(no_conditions) > 0:
#         members.append(no_conditions)
#     for bs in with_conditions:
#         if len(members) > 0:
#             members.append(scg.new_op("+"))
#         members.extend(_conditional_to_starlark(bs))
#     return scg.new_expr(*members)

# def _conditional_to_starlark(with_condition):
#     return []

def _kind_handler(transform, default = None):
    return struct(
        transform = transform,
        default = default,
    )

def _to_starlark(values, kind_handlers = {}):
    # DEBUG BEGIN
    print("*** CHUCK to_starlark values: ")
    for idx, item in enumerate(values):
        print("*** CHUCK", idx, ":", item)
    print("*** CHUCK kind_handlers: ")
    for key in kind_handlers:
        print("*** CHUCK", key, ":", kind_handlers[key])

    # DEBUG END
    # TODO(chuck): IMPLEMENT ME!
    return []

spm_conditions = struct(
    kind_handler = _kind_handler,
    new = _new,
    new_default = _new_default,
    new_from_build_setting = _new_from_build_setting,
    to_starlark = _to_starlark,
)
