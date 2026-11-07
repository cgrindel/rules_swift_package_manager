"""Pure rendering of the SDK provider's BUILD and metadata contract."""

load(":profiles.bzl", "sdk_scan_profiles")

def _render(upstream, repo_name, hub_label, configuration_labels, resolve_label, scan):
    for sdk, triple in scan["targets"].items():
        error = sdk_scan_profiles.error(sdk, triple)
        if error:
            fail(error)
    modules = {}
    conditions = {}
    build = [
        'load("@bazel_skylib//lib:selects.bzl", "selects")',
        'load("@rules_cc//cc:cc_library.bzl", "cc_library")',
        'package(default_visibility = ["//visibility:public"])',
        'exports_files(["modules.json"])',
        'config_setting(name = "compilation_fastbuild", values = {"compilation_mode": "fastbuild"})',
    ]
    for module, entries in sorted(upstream.modules.items()):
        refs = []
        for entry in entries:
            sdk = entry["sdk"]
            if sdk not in scan.get("targets", {}):
                continue
            refs.append(sdk)
            if sdk in conditions:
                continue
            name = "sdk_" + sdk
            sdk_name = name + "_platform"
            constraints = [resolve_label(c) for c in upstream.constraints[entry["sdk_repo"]][entry["sdk_condition"]]]
            arch = scan["targets"][sdk].split("-")[0]
            cpu = {"arm64": "aarch64", "x86_64": "x86_64"}.get(arch)
            if not cpu:
                fail("Unsupported SDK scan architecture: " + arch)
            constraints.append(resolve_label("@platforms//cpu:" + cpu))
            build.append("config_setting(name = {}, constraint_values = {})".format(repr(sdk_name), repr(constraints)))
            match_all = [hub_label + entry["xcode_condition"][1:], ":" + sdk_name]
            build.append("selects.config_setting_group(name = {}, match_all = {})".format(repr(name), repr(match_all)))
            configurations = {}
            for config in ["debug", "release", "fastbuild"]:
                config_name = name + "_" + config
                build.append("selects.config_setting_group(name = {}, match_all = {})".format(repr(config_name), repr(match_all + [":compilation_fastbuild" if config == "fastbuild" else configuration_labels[config]])))
                configurations[config] = "@@{}//:{}".format(repo_name, config_name)
            conditions[sdk] = {
                "condition": "@@{}//:{}".format(repo_name, name),
                "configurations": configurations,
                "environment": entry["environment"],
                "platform": entry["platform"],
                "sdk": sdk,
            }
        if refs:
            modules[module] = sorted(refs)
    error = "SDK inference has no scan profile for this build's Xcode, CPU, SDK and device/simulator environment. Configured Xcode: {}. Configured targets: {}. Match these profiles or disable system_sdk_deps and supply manual dependencies.".format(
        scan["xcode_version"].replace("\n", "; "),
        ", ".join([sdk + "=" + triple for sdk, triple in sorted(scan["targets"].items())]),
    )
    build.append("cc_library(name = \"scan_profile\", deps = select({}, no_match_error = {}))".format(
        repr({":sdk_" + sdk: [] for sdk in sorted(conditions)}),
        repr(error),
    ))
    scan = dict(scan, guard = "@@{}//:scan_profile".format(repo_name))
    return struct(
        build = "\n".join(build) + "\n",
        metadata = {
            "conditions": conditions,
            "diagnostic": "",
            "modules": modules,
            "scan": scan,
            "schema_version": 2,
        },
    )

def _unsupported_host(host):
    return struct(
        build = 'exports_files(["modules.json"], visibility = ["//visibility:public"])\n',
        metadata = {
            "conditions": {},
            "diagnostic": "Apple SDK inference is inactive on the {} fetch host; no Apple compiler or SDK is fetched.".format(host),
            "modules": {},
            "scan": {"host_supported": False},
            "schema_version": 2,
        },
    )

sdk_inventory_render = struct(render = _render, unsupported_host = _unsupported_host)
