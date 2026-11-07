"""Platform-scoped module graph regression tests."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:dependency_modules.bzl", "dependency_modules")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")

def _target(name, dependencies = [], module = None):
    return struct(name = name, c99name = name, type = "regular", dependencies = dependencies, clang_src_info = struct(module_name = module) if module else None)

def _target_ref(name, platforms = []):
    return pkginfos.new_target_dependency(target = pkginfos.new_target_reference(name, pkginfos.new_target_dependency_condition(platforms = platforms)))

def _product_ref(platforms = []):
    return pkginfos.new_target_dependency(product = pkginfos.new_product_reference("Modules", "provider", pkginfos.new_target_dependency_condition(platforms = platforms)))

def _local_modules_test(ctx):
    env = unittest.begin(ctx)
    info = struct(name = "Local", products = [], dependencies = [], targets = [
        _target("Consumer", [_target_ref("CDispatch", ["ios"])]),
        _target("CDispatch", module = "Dispatch"),
        _target("UIKit"),
    ])
    result = dependency_modules.for_package(info, {}, ["ios", "macos"])
    asserts.equals(env, ["Consumer", "Dispatch"], result["Consumer"]["ios"])
    asserts.equals(env, ["Consumer"], result["Consumer"]["macos"])
    asserts.equals(env, ["Dispatch"], result["CDispatch"]["macos"])
    return unittest.end(env)

local_modules_test = unittest.make(_local_modules_test)

def _external_modules_test(ctx):
    env = unittest.begin(ctx)
    info = struct(name = "Local", products = [], dependencies = [pkginfos.new_dependency(identity = "provider", name = "provider")], targets = [
        _target("MacConsumer", [_product_ref(["macos"])]),
        _target("AllConsumer", [_product_ref()]),
        _target("LinuxConsumer", [_product_ref(["linux"])]),
        _target("IndirectConsumer", [_target_ref("AllConsumer", ["ios"])]),
    ])

    # This is the JSON shape exported by dependency repositories, including a
    # module-map name that differs from its target and a conditional local edge.
    metadata = {"provider": {
        "name": "Provider",
        "products": [{"name": "Modules", "targets": ["Facade"]}],
        "targets": [
            {
                "c99name": "Facade",
                "dependencies": [
                    {"target": {"condition": {"platforms": ["macos"]}, "target_name": "CDispatch"}},
                ],
                "name": "Facade",
            },
            {"c99name": "CDispatch", "clang_src_info": {"module_name": "Dispatch"}, "name": "CDispatch"},
        ],
    }}
    result = dependency_modules.for_package(info, metadata, ["ios", "macos", "linux"])
    asserts.equals(env, ["MacConsumer"], result["MacConsumer"]["ios"])
    asserts.equals(env, ["Dispatch", "Facade", "MacConsumer"], result["MacConsumer"]["macos"])
    asserts.equals(env, ["AllConsumer", "Facade"], result["AllConsumer"]["ios"])
    asserts.equals(env, ["AllConsumer", "Dispatch", "Facade"], result["AllConsumer"]["macos"])
    asserts.equals(env, ["LinuxConsumer"], result["LinuxConsumer"]["macos"])
    asserts.equals(env, ["Facade", "LinuxConsumer"], result["LinuxConsumer"]["linux"])
    asserts.equals(env, ["AllConsumer", "Facade", "IndirectConsumer"], result["IndirectConsumer"]["ios"])
    asserts.equals(env, ["IndirectConsumer"], result["IndirectConsumer"]["macos"])
    return unittest.end(env)

external_modules_test = unittest.make(_external_modules_test)

def _transitive_modules_test(ctx):
    env = unittest.begin(ctx)
    info = struct(name = "Consumer", products = [], dependencies = [pkginfos.new_dependency(identity = "provider", name = "provider")], targets = [
        _target("Consumer", [_product_ref()]),
    ])
    metadata = {"provider": {
        "dependencies": [{"identity": "testing", "name": "test-helpers"}],
        "name": "Provider",
        "products": [{"name": "Modules", "targets": ["Helper"]}],
        "targets": [{
            "c99name": "Helper",
            "dependencies": [
                {"product": {"condition": {"platforms": ["macos"]}, "dep_name": "test-helpers", "product_name": "TestSupport"}},
            ],
            "name": "Helper",
        }],
    }}
    partial = dependency_modules.resolve(info, metadata, ["ios", "macos"])
    asserts.equals(env, ["testing"], partial.missing)
    asserts.equals(env, [], dependency_modules.resolve(info, metadata, ["ios"]).missing)
    metadata["testing"] = {
        "dependencies": [{"identity": "provider", "name": "provider"}],
        "name": "Testing",
        "products": [{"name": "TestSupport", "targets": ["Testing"]}],
        "targets": [
            {
                "c99name": "Testing",
                "dependencies": [
                    {"target": {"target_name": "CObjC"}},
                    # An external cycle must terminate without dropping other edges.
                    {"product": {"dep_name": "provider", "product_name": "Modules"}},
                ],
                "name": "Testing",
            },
            {"c99name": "CObjC", "clang_src_info": {"module_name": "ObjectiveC"}, "name": "CObjC"},
        ],
    }
    result = dependency_modules.resolve(info, metadata, ["ios", "macos"])
    asserts.equals(env, [], result.missing)
    asserts.equals(env, {"Consumer": {
        "ios": ["Consumer", "Helper"],
        "macos": ["Consumer", "Helper", "ObjectiveC", "Testing"],
    }}, result.modules)
    return unittest.end(env)

transitive_modules_test = unittest.make(_transitive_modules_test)

def dependency_modules_test_suite():
    unittest.suite("dependency_modules_tests", local_modules_test, external_modules_test, transitive_modules_test)
