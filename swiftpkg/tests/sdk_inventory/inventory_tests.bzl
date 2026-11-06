"""SDK inventory adapter contract tests."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal/sdk_inventory:parser.bzl", "system_sdk_inventory")
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
        "schema_version": 1,
    }))
    asserts.equals(env, [{"condition": "//:macos"}], system_sdk_modules.entries(compact, "Foundation"))
    asserts.equals(env, [], system_sdk_modules.entries(compact, "Unknown"))
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

def system_sdk_inventory_test_suite():
    unittest.suite("system_sdk_inventory_tests", inventory_test, upstream_format_test)
