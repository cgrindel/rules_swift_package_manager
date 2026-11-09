"""Pure rendering of the SDK provider's BUILD and metadata contract."""

load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load("//swiftpkg/internal:build_files.bzl", "build_files")
load("//swiftpkg/internal:load_statements.bzl", "load_statements")
load(
    "//swiftpkg/internal:starlark_codegen.bzl",
    scg = "starlark_codegen",
)
load(":profiles.bzl", "sdk_scan_profiles")

_SCHEMA_VERSION = 2

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

_UNSUPPORTED_HOST_TMPL = """\
Apple SDK inference is inactive on the {host} fetch host; no Apple compiler \
or SDK is fetched.\
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

def _render(
        upstream,
        repo_name,
        hub_label,
        configuration_labels,
        resolve_label,
        scan):
    """Render the SDK inventory repository's BUILD file and metadata.

    Args:
        upstream: The parsed rules_swift SDK inventory `struct`.
        repo_name: The canonical name of the inventory repository.
        hub_label: The label prefix of the rules_swift SDK hub repository.
        configuration_labels: A `dict` mapping `debug` and `release` to their
            config setting labels.
        resolve_label: A function that resolves a label `string`.
        scan: The scan settings as a `dict`.

    Returns:
        A `struct` with `build` (a build file `struct` as returned by
        `build_files.new`) and `metadata` (a `dict`).
    """
    for sdk, triple in scan["targets"].items():
        error = sdk_scan_profiles.error(sdk, triple)
        if error:
            fail(error)

    modules = {}
    conditions = {}
    sdk_decls = []
    for module, entries in sorted(upstream.modules.items()):
        refs = []
        for entry in entries:
            sdk = entry["sdk"]
            if sdk not in scan.get("targets", {}):
                continue
            refs.append(sdk)
            if sdk in conditions:
                continue

            arch = scan["targets"][sdk].split("-")[0]
            cpu = _CPU_BY_ARCH.get(arch)
            if not cpu:
                fail("Unsupported SDK scan architecture: " + arch)
            sdk_repo_constraints = upstream.constraints[entry["sdk_repo"]]
            sdk_condition = sdk_repo_constraints[entry["sdk_condition"]]
            constraints = [resolve_label(c) for c in sdk_condition]
            constraints.append(resolve_label("@platforms//cpu:" + cpu))

            name = "sdk_" + sdk
            sdk_decls.extend(_sdk_decls(
                name = name,
                constraints = constraints,
                xcode_setting = hub_label + entry["xcode_condition"][1:],
                configuration_labels = configuration_labels,
            ))
            conditions[sdk] = {
                "condition": "@@{}//:{}".format(repo_name, name),
                "configurations": {
                    config: "@@{}//:{}_{}".format(repo_name, name, config)
                    for config in ["debug", "release", "fastbuild"]
                },
                "environment": entry["environment"],
                "platform": entry["platform"],
                "sdk": sdk,
            }
        if refs:
            modules[module] = sorted(refs)

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

    decls = [
        scg.new_fn_call("exports_files", ["modules.json"]),
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

def _unsupported_host(host):
    """Render an inactive inventory for a host without Apple SDKs.

    Args:
        host: The fetch host's OS name as a `string`.

    Returns:
        A `struct` with `build` and `metadata`, like `render`.
    """
    build = build_files.new(
        decls = [
            scg.new_fn_call(
                "exports_files",
                ["modules.json"],
                visibility = ["//visibility:public"],
            ),
        ],
    )
    return struct(
        build = build,
        metadata = {
            "conditions": {},
            "diagnostic": _UNSUPPORTED_HOST_TMPL.format(host = host),
            "modules": {},
            "scan": {"host_supported": False},
            "schema_version": _SCHEMA_VERSION,
        },
    )

sdk_inventory_render = struct(
    render = _render,
    schema_version = _SCHEMA_VERSION,
    unsupported_host = _unsupported_host,
)
