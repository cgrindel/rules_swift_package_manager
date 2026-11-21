"""Pure rendering of the SDK provider's BUILD and metadata contract."""

load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load("//swiftpkg/internal:build_files.bzl", "build_files")
load("//swiftpkg/internal:load_statements.bzl", "load_statements")
load(
    "//swiftpkg/internal:starlark_codegen.bzl",
    scg = "starlark_codegen",
)
load(":sdks.bzl", "sdks")

_SCHEMA_VERSION = 3

_SELECTS_LOCATION = "@bazel_skylib//lib:selects.bzl"
_CC_LIBRARY_LOCATION = "@rules_cc//cc:cc_library.bzl"

_CONFIG_SETTING_GROUP = "selects.config_setting_group"

_FASTBUILD_SETTING = "compilation_fastbuild"

_CPU_BY_ARCH = {"arm64": "aarch64", "x86_64": "x86_64"}

_NO_MATCH_ERROR_TMPL = """\
SDK inference has no scan profile for this build's Xcode, CPU, SDK and \
device/simulator environment. Configured Xcode: {xcode}. Configured targets: \
{targets}. Include a MacOSX profile for exec tools/macros and a device \
profile for device builds. Match these profiles, disable system_sdk_deps, or \
set \
--@rules_swift_package_manager//config_settings/sdk_inference:strict_profile=false \
where blanket or manual SDK dependencies cover unmatched profiles.\
"""

def _sdk_decls(name, constraints, xcode_setting, configuration_labels):
    """Create the config settings that select one SDK profile.

    Args:
        name: The base name for the declarations as a `string`.
        constraints: The platform constraint labels as a `list` of `string`.
        xcode_setting: The label of the hub's Xcode condition as a `string`.
        configuration_labels: A `dict` mapping `debug` and `release` to their
            config setting labels.

    Returns:
        A `list` of build declarations.
    """
    platform_name = name + "_platform"
    match_all = [xcode_setting, ":" + platform_name]
    decls = [
        build_decls.new(
            kind = "config_setting",
            name = platform_name,
            attrs = {"constraint_values": constraints},
        ),
        build_decls.new(
            kind = _CONFIG_SETTING_GROUP,
            name = name,
            attrs = {"match_all": match_all},
        ),
    ]
    for config in ["debug", "release", "fastbuild"]:
        if config == "fastbuild":
            config_setting = ":" + _FASTBUILD_SETTING
        else:
            config_setting = configuration_labels[config]
        decls.append(build_decls.new(
            kind = _CONFIG_SETTING_GROUP,
            name = name + "_" + config,
            attrs = {"match_all": match_all + [config_setting]},
        ))
    return decls

def _render(cache, repo_name, configuration_labels, resolve_label):
    """Render configuration labels from portable cache IDs, without host reads."""
    scan = dict(
        cache["request"],
        xcode_version = cache["xcode_version"],
        swift_version = cache["swift_version"],
        fingerprints = cache["fingerprints"],
        package_names = sorted(cache.get("packages", {})),
    )
    modules = cache["modules"]
    conditions = {}
    sdk_decls = [build_decls.new(
        kind = "config_setting",
        name = "cached_xcode",
        attrs = {"flag_values": {resolve_label("@bazel_tools//tools/osx:xcode_version_flag_exact"): cache["xcode_version"]}},
    )]
    for sdk, triple in sorted(scan["targets"].items()):
        sdk_info = sdks.get(sdk)
        constraints = [resolve_label("@platforms//os:" + sdk_info.platform)]
        if sdk != "MacOSX":
            constraints.append(resolve_label("@apple_support//constraints:" + sdk_info.environment))
        constraints.append(resolve_label("@platforms//cpu:" + _CPU_BY_ARCH[triple.split("-")[0]]))
        name = "sdk_" + sdk
        sdk_decls.extend(_sdk_decls(name, constraints, ":cached_xcode", configuration_labels))
        conditions[sdk] = {
            "condition": "@@{}//:{}".format(repo_name, name),
            "configurations": {
                config: "@@{}//:{}_{}".format(repo_name, name, config)
                for config in ["debug", "release", "fastbuild"]
            },
            "environment": sdk_info.environment,
            "platform": sdk_info.platform,
            "sdk": sdk,
        }

    no_match_error = _NO_MATCH_ERROR_TMPL.format(
        xcode = scan["xcode_version"].replace("\n", "; "),
        targets = ", ".join([
            sdk + "=" + triple
            for sdk, triple in sorted(scan["targets"].items())
        ]),
    )
    profiles = {":sdk_" + sdk: [] for sdk in sorted(conditions)}

    # This branch permits unmatched profiles only when explicitly requested.
    # Multiple matches are unambiguous: all branches have the same empty value.
    allow_unmatched = resolve_label(
        "//config_settings/sdk_inference:allow_unmatched_profile",
    )
    profiles[allow_unmatched] = []
    profiles[resolve_label("@platforms//os:linux")] = []

    decls = [
        scg.new_fn_call(
            "exports_files",
            ["modules.json"] + [
                "packages/" + name + ".json"
                for name in scan["package_names"]
            ],
        ),
        build_decls.new(
            kind = "config_setting",
            name = _FASTBUILD_SETTING,
            attrs = {"values": {"compilation_mode": "fastbuild"}},
        ),
    ]
    decls.extend(sdk_decls)
    decls.append(build_decls.new(
        kind = "cc_library",
        name = "scan_profile",
        attrs = {
            "deps": scg.new_fn_call(
                "select",
                profiles,
                no_match_error = no_match_error,
            ),
        },
    ))

    build = build_files.new(
        load_stmts = [
            load_statements.new(_SELECTS_LOCATION, "selects"),
            load_statements.new(_CC_LIBRARY_LOCATION, "cc_library"),
        ],
        package_attrs = {"default_visibility": ["//visibility:public"]},
        decls = decls,
    )
    guard = "@@{}//:scan_profile".format(repo_name)
    return struct(
        build = build,
        metadata = {
            "conditions": conditions,
            "diagnostic": "",
            "modules": modules,
            "scan": dict(scan, guard = guard),
            "schema_version": _SCHEMA_VERSION,
        },
    )

sdk_inventory_render = struct(
    render = _render,
    schema_version = _SCHEMA_VERSION,
)
