"""SDK inventory adapter contract tests."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal/sdk_inventory:inputs.bzl", "sdk_inventory_inputs")
load("//swiftpkg/internal/sdk_inventory:parser.bzl", "system_sdk_inventory")
load("//swiftpkg/internal/sdk_inventory:profiles.bzl", "sdk_scan_profiles")
load("//swiftpkg/internal/sdk_inventory:render.bzl", "sdk_inventory_render")
load("//swiftpkg/internal/sdk_inventory:repository.bzl", "system_sdk_modules")
load(":build_fixtures.bzl", "HUB_BUILD", "XCODE_BUILD")

def _alias(name, branches):
    return "alias(\n    name = " + json.encode(name) + ",\n    actual = select({\n" + "\n".join([
        "        " + json.encode(k) + ": " + json.encode(v) + ","
        for k, v in branches.items()
    ]) + "\n    }),\n)\n"

def _sdk_alias(name, sdks):
    return _alias(name, {":" + sdk + "_sdk": ":" + sdk + "_" + name for sdk in sdks})

def _inventory_test(ctx):
    env = unittest.begin(ctx)
    names = ["Foundation", "UIKit", "Darwin", "Dispatch", "NewModule", "ExcludedModule", "DeviceOnly"]
    hub_text = "".join([
        _alias(name, {":xcode_1": "@system_sdk_xcode_1//:" + name, ":xcode_2": "@system_sdk_xcode_2//:" + name})
        for name in names
    ])
    all_sdks = ["MacOSX", "iPhoneOS", "iPhoneSimulator"]
    first = "".join([_sdk_alias(n, all_sdks) for n in names])
    second = "".join([_sdk_alias(n, all_sdks) for n in ["Foundation", "Darwin", "Dispatch"]])
    second += _sdk_alias("UIKit", ["iPhoneOS", "iPhoneSimulator"])
    second += _sdk_alias("ExcludedModule", ["MacOSX"])
    second += _sdk_alias("DeviceOnly", ["iPhoneOS"])
    result = system_sdk_inventory.inventory(
        system_sdk_inventory.aliases(hub_text),
        {
            "@system_sdk_xcode_1": system_sdk_inventory.aliases(first),
            "@system_sdk_xcode_2": system_sdk_inventory.aliases(second),
        },
    )
    asserts.equals(env, 6, len(result["Foundation"]))
    asserts.equals(env, 5, len(result["UIKit"]))
    asserts.equals(env, 4, len(result["DeviceOnly"]))
    asserts.equals(env, 3, len(result["NewModule"]))
    asserts.equals(env, "ios", result["DeviceOnly"][-1]["platform"])
    asserts.equals(env, ":iPhoneOS_sdk", result["DeviceOnly"][-1]["sdk_condition"])
    asserts.equals(env, {}, system_sdk_inventory.aliases('system_module_group(name = "all_modules")'))
    asserts.equals(env, None, system_sdk_inventory.aliases('alias(name = "Foundation", actual = ":custom")'))
    asserts.equals(env, None, system_sdk_inventory.aliases('alias(\nname = "X",\nactual = ":X",\n)'))
    compact = system_sdk_modules.decode(json.encode({
        "conditions": {"0": {"condition": "//:macos"}},
        "diagnostic": "",
        "modules": {"Foundation": ["0"], "Unused": ["missing"]},
        "scan": {},
        "schema_version": 2,
    }))
    asserts.equals(env, [{"condition": "//:macos"}], [compact.conditions[i] for i in compact.modules["Foundation"]])
    asserts.equals(env, [], compact.modules.get("Unknown", []))
    return unittest.end(env)

inventory_test = unittest.make(_inventory_test)

def _upstream_format_test(ctx):
    env = unittest.begin(ctx)
    hub = system_sdk_inventory.aliases(HUB_BUILD)
    sdk = system_sdk_inventory.aliases(XCODE_BUILD)
    constraints = system_sdk_inventory.sdk_constraints(XCODE_BUILD)
    result = system_sdk_inventory.inventory(hub, {"@system_sdk_xcode_27_0_0_27A266a": sdk})
    asserts.equals(env, ["Dispatch", "Foundation", "UIKit"], sorted(result))
    asserts.equals(env, ["ios", "ios"], [e["platform"] for e in result["UIKit"]])
    asserts.equals(env, ["device", "simulator"], [e["environment"] for e in result["UIKit"]])
    asserts.equals(env, ["@platforms//os:macos"], constraints[":MacOSX_sdk"])
    asserts.equals(env, ["@platforms//os:ios", "@apple_support//constraints:simulator"], constraints[":iPhoneSimulator_sdk"])
    asserts.equals(env, None, system_sdk_inventory.sdk_constraints(XCODE_BUILD.replace("@platforms//os:macos", "@unknown//:os")))
    asserts.equals(env, None, system_sdk_inventory.aliases(HUB_BUILD.replace("actual = select({", "actual = unexpected({")))
    return unittest.end(env)

upstream_format_test = unittest.make(_upstream_format_test)

def _repository_test(ctx):
    env = unittest.begin(ctx)
    sdk_build = Label("@system_sdk//:BUILD.bazel")
    reads = []

    # A broken second Xcode must never be fetched merely because it is installed.
    hub = HUB_BUILD.replace("    }),", '        ":xcode_unused": "@system_sdk_xcode_unused//:all_modules",\n    }),')

    # Only the all_modules branch is needed to choose the repository; retain
    # correctly named aliases in the other blocks.
    hub = HUB_BUILD.replace('"@system_sdk_xcode_27_0_0_27A266a//:all_modules",', '"@system_sdk_xcode_27_0_0_27A266a//:all_modules",\n        ":xcode_unused": "@system_sdk_xcode_unused//:all_modules",')

    def read(label):
        reads.append(str(label))
        if label == sdk_build:
            return hub
        asserts.true(env, "system_sdk_xcode_27_0_0_27A266a//:" in str(label), str(label))
        return XCODE_BUILD

    upstream = system_sdk_modules.read_upstream(struct(read = read), sdk_build, "Xcode 27.0\nBuild version 27A266a")
    asserts.equals(env, 2, len(reads))
    scan = {"targets": {"MacOSX": "arm64-apple-macosx14.0"}, "xcode_version": "Xcode 27.0\nBuild version 27A266a"}
    result = sdk_inventory_render.render(upstream, "inventory", "@sdk//:", {"debug": "//:debug", "release": "//:release"}, lambda x: x, scan)
    asserts.equals(env, {
        "conditions": {"MacOSX": {
            "condition": "@@inventory//:sdk_MacOSX",
            "configurations": {"debug": "@@inventory//:sdk_MacOSX_debug", "fastbuild": "@@inventory//:sdk_MacOSX_fastbuild", "release": "@@inventory//:sdk_MacOSX_release"},
            "environment": "device",
            "platform": "macos",
            "sdk": "MacOSX",
        }},
        "diagnostic": "",
        "modules": {"Dispatch": ["MacOSX"], "Foundation": ["MacOSX"]},
        "scan": dict(scan, guard = "@@inventory//:scan_profile"),
        "schema_version": 2,
    }, result.metadata)
    asserts.equals(env, '''load("@bazel_skylib//lib:selects.bzl", "selects")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
package(default_visibility = ["//visibility:public"])
exports_files(["modules.json"])
config_setting(name = "compilation_fastbuild", values = {"compilation_mode": "fastbuild"})
config_setting(name = "sdk_MacOSX_platform", constraint_values = ["@platforms//os:macos", "@platforms//cpu:aarch64"])
selects.config_setting_group(name = "sdk_MacOSX", match_all = ["@sdk//:xcode_27_0_0_27A266a", ":sdk_MacOSX_platform"])
selects.config_setting_group(name = "sdk_MacOSX_debug", match_all = ["@sdk//:xcode_27_0_0_27A266a", ":sdk_MacOSX_platform", "//:debug"])
selects.config_setting_group(name = "sdk_MacOSX_release", match_all = ["@sdk//:xcode_27_0_0_27A266a", ":sdk_MacOSX_platform", "//:release"])
selects.config_setting_group(name = "sdk_MacOSX_fastbuild", match_all = ["@sdk//:xcode_27_0_0_27A266a", ":sdk_MacOSX_platform", ":compilation_fastbuild"])
cc_library(name = "scan_profile", deps = select({":sdk_MacOSX": []}, no_match_error = "SDK inference has no scan profile for this build\'s Xcode, CPU, SDK and device/simulator environment. Configured Xcode: Xcode 27.0; Build version 27A266a. Configured targets: MacOSX=arm64-apple-macosx14.0. Match these profiles or disable system_sdk_deps and supply manual dependencies."))
''', result.build)
    return unittest.end(env)

repository_test = unittest.make(_repository_test)

def _format_variants_test(ctx):
    env = unittest.begin(ctx)
    decorated = HUB_BUILD.replace("alias(\n", 'alias(\n    # comment\n    tags = ["manual"],\n    visibility = ["//visibility:public"],\n')
    asserts.equals(env, system_sdk_inventory.aliases(HUB_BUILD), system_sdk_inventory.aliases(decorated))
    decorated = XCODE_BUILD.replace('visibility = ["//visibility:private"],', 'visibility = ["//visibility:public"], # safe metadata\n    tags = ["manual"],')
    asserts.equals(env, system_sdk_inventory.sdk_constraints(XCODE_BUILD), system_sdk_inventory.sdk_constraints(decorated))
    hub = system_sdk_inventory.aliases(HUB_BUILD)
    sdk = system_sdk_inventory.aliases(XCODE_BUILD)
    sdk["UIKit"]["//conditions:default"] = ":_empty_module"
    result = system_sdk_inventory.inventory(hub, {"@system_sdk_xcode_27_0_0_27A266a": sdk})
    asserts.equals(env, ["iPhoneOS", "iPhoneSimulator"], [entry["sdk"] for entry in result["UIKit"]])
    return unittest.end(env)

format_variants_test = unittest.make(_format_variants_test)

def _watch_cycle_test(ctx):
    env = unittest.begin(ctx)
    reads = []
    watches = []

    def path(name):
        def readdir(watch):
            asserts.equals(env, "yes", watch)
            reads.append(name)
            return ["/SDK/alias", "/SDK/module.modulemap"]

        return struct(
            exists = True,
            realpath = "/SDK" if name == "/SDK/alias" else name,
            is_dir = name in ["/SDK", "/SDK/alias"],
            readdir = readdir,
        )

    manifest = sdk_inventory_inputs.manifest(struct(path = path, watch = lambda p: watches.append(p)), ["/SDK"])
    asserts.equals(env, ["/SDK"], reads)
    asserts.equals(env, ["/SDK/alias", "/SDK/module.modulemap"], watches)
    asserts.equals(env, {
        "files": ["/SDK/module.modulemap"],
        "layout": [
            ["/SDK", "/SDK", "directory"],
            ["/SDK/alias", "/SDK", "directory"],
            ["/SDK/module.modulemap", "/SDK/module.modulemap", "file"],
        ],
    }, manifest)
    return unittest.end(env)

watch_cycle_test = unittest.make(_watch_cycle_test)

def _profiles_test(ctx):
    env = unittest.begin(ctx)
    for sdk, triple in {
        "AppleTVOS": "arm64-apple-tvos17.0",
        "AppleTVSimulator": "arm64-apple-tvos17.0-simulator",
        "MacOSX": "arm64-apple-macosx14.0",
        "WatchOS": "arm64-apple-watchos10.0",
        "WatchSimulator": "arm64-apple-watchos10.0-simulator",
        "XROS": "arm64-apple-xros1.0",
        "XRSimulator": "arm64-apple-xros1.0-simulator",
        "iPhoneOS": "arm64-apple-ios17.0",
        "iPhoneSimulator": "x86_64-apple-ios17.0-simulator",
    }.items():
        asserts.equals(env, None, sdk_scan_profiles.error(sdk, triple))
    for sdk, triple in [
        ("iPhoneSimulator", "arm64-apple-ios17.0"),
        ("iPhoneOS", "arm64-apple-ios17.0-simulator"),
        ("MacOSX", "arm64-apple-ios17.0"),
        ("iPhoneOS", "arm64-apple-ios17.0-macabi"),
        ("iPhoneOS", "x86_64-apple-ios17.0"),
        ("MacOSX", "arm64e-apple-macosx14.0"),
        ("MacOSX", "arm64-unknown-macosx14.0"),
        ("MacOSX", "arm64-apple-macosx"),
        ("Unknown", "arm64-apple-ios17.0"),
    ]:
        asserts.true(env, sdk_scan_profiles.error(sdk, triple) != None, triple)
    environment = sdk_scan_profiles.environment("/Xcode/Developer")
    asserts.equals(env, "/Xcode/Developer", environment["DEVELOPER_DIR"])
    for variable in ["CPATH", "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "OBJC_INCLUDE_PATH", "SDKROOT"]:
        asserts.equals(env, "", environment[variable])
    return unittest.end(env)

profiles_test = unittest.make(_profiles_test)

def _symlink_retarget_test(ctx):
    env = unittest.begin(ctx)

    def manifest(destination):
        def path(name):
            return struct(
                exists = True,
                realpath = destination if name == "/SDK/current" else name,
                is_dir = name == "/SDK",
                readdir = lambda watch: ["/SDK/A", "/SDK/B", "/SDK/current"],
            )

        return sdk_inventory_inputs.manifest(struct(path = path, watch = lambda p: None), ["/SDK"])

    before = manifest("/SDK/A")
    after = manifest("/SDK/B")
    asserts.equals(env, before["files"], after["files"])
    asserts.true(env, before["layout"] != after["layout"])
    return unittest.end(env)

symlink_retarget_test = unittest.make(_symlink_retarget_test)

def _host_and_selection_test(ctx):
    env = unittest.begin(ctx)
    outputs = {}

    # Deliberately omit attrs/execute/read: Linux must return before any SDK work.
    system_sdk_modules.generate(struct(os = struct(name = "linux"), file = lambda name, content: outputs.update({name: content})))
    metadata = system_sdk_modules.decode(outputs["modules.json"])
    asserts.equals(env, {}, metadata.modules)
    asserts.equals(env, {}, metadata.conditions)
    asserts.equals(env, {"host_supported": False}, metadata.scan)
    asserts.true(env, "linux" in metadata.diagnostic)
    for environment, configured in [("/Xcode", ""), (None, "/Xcode"), ("/Xcode", "/Xcode")]:
        def getenv(name):
            asserts.equals(env, "DEVELOPER_DIR", name)
            return environment

        repo = struct(attr = struct(developer_dir = configured), getenv = getenv, path = lambda p: struct(realpath = p))
        asserts.equals(env, "/Xcode", system_sdk_modules.developer_dir(repo))
    return unittest.end(env)

host_and_selection_test = unittest.make(_host_and_selection_test)

def system_sdk_inventory_test_suite():
    unittest.suite("system_sdk_inventory_tests", inventory_test, upstream_format_test, repository_test, format_variants_test, watch_cycle_test, profiles_test, symlink_retarget_test, host_and_selection_test)
