"""Portable SDK cache contract and host-free repository tests."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal/sdk_inventory:profiles.bzl", "sdk_scan_profiles")
load("//swiftpkg/internal/sdk_inventory:render.bzl", "sdk_inventory_render")
load("//swiftpkg/internal/sdk_inventory:repository.bzl", "system_sdk_modules")

_REQUEST = {
    "defines": None,
    "exclude_modules": None,
    "full_sdk_tracking": False,
    "targets": {"MacOSX": "arm64-apple-macosx13.0", "iPhoneSimulator": "arm64-apple-ios15.0-simulator"},
}
_CACHE = {
    "fingerprints": {"compiler/swiftc": "a" * 64},
    "modules": {"Foundation": ["MacOSX", "iPhoneSimulator"], "UIKit": ["iPhoneSimulator"]},
    "request": _REQUEST,
    "schema_version": 3,
    "swift_version": "Apple Swift version 6.3",
    "xcode_version": "27.0.0.27A266a",
}

def _render_test(ctx):
    env = unittest.begin(ctx)
    result = sdk_inventory_render.render(_CACHE, "inventory", {"debug": "//:debug", "release": "//:release"}, lambda label: label)
    asserts.equals(env, _CACHE["modules"], result.metadata["modules"])
    asserts.equals(env, {
        "condition": "@@inventory//:sdk_iPhoneSimulator",
        "configurations": {
            "debug": "@@inventory//:sdk_iPhoneSimulator_debug",
            "fastbuild": "@@inventory//:sdk_iPhoneSimulator_fastbuild",
            "release": "@@inventory//:sdk_iPhoneSimulator_release",
        },
        "environment": "simulator",
        "platform": "ios",
        "sdk": "iPhoneSimulator",
    }, result.metadata["conditions"]["iPhoneSimulator"])
    asserts.equals(env, "@@inventory//:scan_profile", result.metadata["scan"]["guard"])
    return unittest.end(env)

render_test = unittest.make(_render_test)

def _repository_test(ctx):
    env = unittest.begin(ctx)
    reads = []
    files = {}
    inputs = {"cache": json.encode(_CACHE), "request": json.encode(_REQUEST)}

    def read(path):
        reads.append(path)
        return inputs[path]

    def file(path, content = "", executable = False, legacy_utf8 = False):
        asserts.false(env, executable)
        asserts.false(env, legacy_utf8)
        files[path] = content

    # No execute(), getenv(), os, watch(), readdir(), or SDK paths are provided.
    # Generation must succeed solely from declared source JSON labels.
    system_sdk_modules.generate(struct(
        name = "inventory",
        attr = struct(cache = "cache", request = "request", generator = "//:update_cache"),
        path = lambda path: struct(exists = True),
        read = read,
        file = file,
    ))
    asserts.equals(env, ["request", "cache"], reads)
    decoded = system_sdk_modules.decode(files["modules.json"])
    asserts.equals(env, _CACHE["modules"], decoded.modules)
    asserts.true(env, "BUILD.bazel" in files)
    asserts.false(env, "/Applications/" in files["modules.json"])
    asserts.false(env, "system_sdk_xcode_" in files["BUILD.bazel"])
    asserts.true(env, 'name = "cached_xcode"' in files["BUILD.bazel"])
    asserts.true(env, "xcode_version_flag_exact" in files["BUILD.bazel"])
    asserts.true(env, "27.0.0.27A266a" in files["BUILD.bazel"])
    return unittest.end(env)

repository_test = unittest.make(_repository_test)

def _profiles_test(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, None, sdk_scan_profiles.error("MacOSX", "arm64-apple-macosx13.0"))
    asserts.equals(env, None, sdk_scan_profiles.error("iPhoneSimulator", "x86_64-apple-ios16.0-simulator"))
    asserts.true(env, sdk_scan_profiles.error("iPhoneSimulator", "arm64-apple-ios16.0") != None)
    asserts.true(env, sdk_scan_profiles.error("iPhoneOS", "arm64e-apple-ios16.0") != None)
    return unittest.end(env)

profiles_test = unittest.make(_profiles_test)

def _package_slice_test(ctx):
    env = unittest.begin(ctx)
    own = {"inputs": {"Package.swift": "a" * 64}, "targets": {}}
    cache = dict(_CACHE, packages = {
        "swiftpkg_one": own,
        "swiftpkg_other": {"inputs": {}, "targets": {"Unrelated": {}}},
    })
    rendered = sdk_inventory_render.render(
        cache,
        "inventory",
        {"debug": "//:debug", "release": "//:release"},
        lambda label: label,
    )
    asserts.false(env, "packages" in rendered.metadata["scan"])
    reads = []

    def read(label):
        label = str(label)
        reads.append(label)
        if label.endswith("//:modules.json"):
            return json.encode(rendered.metadata)
        asserts.true(env, label.endswith("//:packages/swiftpkg_one.json"))
        return json.encode(own)

    result = system_sdk_modules.read(struct(
        name = "extension+swiftpkg_one",
        attr = struct(bazel_package_name = "swiftpkg_one"),
        read = read,
    ))
    asserts.equals(env, 2, len(reads))
    asserts.equals(env, {"swiftpkg_one": own}, result.scan["packages"])
    return unittest.end(env)

package_slice_test = unittest.make(_package_slice_test)

def system_sdk_inventory_test_suite():
    unittest.suite("system_sdk_inventory_tests", render_test, repository_test, profiles_test, package_slice_test)
