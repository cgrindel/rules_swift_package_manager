"""
Module for transforming Swift package manifest conditionals to Starlark.
"""

def _new(identifier, condition, value):
    return struct(
        identifier = identifier,
        condition = condition,
        value = value,
    )

def _new_default(identifier, value):
    return _new(
        identifier = identifier,
        condition = "//conditions:default",
        value = value,
    )

# GH153: Finish conditional support.

# def _new_from_build_setting(build_setting):
#     bsc = build_setting.condition
#     results = []
#     for platform in bsc.platforms:
#         pass
#     return results

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
#       "@cgrindel_swift_bazel//config_settings/platform_types:macos": ["AppKit"],
#       "@cgrindel_swift_bazel//config_settings/platform_types:ios": ["UIKit"],
#       "@cgrindel_swift_bazel//config_settings/platform_types:tvos": ["UIKit"],
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

spm_conditionals = struct(
    new = _new,
    new_default = _new_default,
)
