"""Compiler command construction, dependency metadata and report regression tests."""

load("@bazel_skylib//lib:structs.bzl", "structs")
load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:compiler_imports.bzl", "compiler_imports")
load("//swiftpkg/internal:pkg_ctxs.bzl", "pkg_ctxs")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:sdk_inference_context.bzl", "sdk_inference_context")

def _fixture():
    target = pkginfos.new_target(
        name = "Consumer",
        type = "regular",
        c99name = "Consumer",
        module_type = "SwiftTarget",
        path = "Sources",
        sources = ["Consumer.swift"],
        repo_name = "swiftpkg_consumer",
        swift_src_info = pkginfos.new_swift_src_info(),
        swift_settings = pkginfos.new_swift_settings([
            pkginfos.new_build_setting("define", ["IOS_ONLY"], pkginfos.new_build_setting_condition(platforms = ["ios"])),
            pkginfos.new_build_setting("define", ["RELEASE_ONLY"], pkginfos.new_build_setting_condition(configuration = "release")),
        ]),
        linker_settings = pkginfos.new_linker_settings([pkginfos.new_build_setting("linkedFramework", ["Security"], pkginfos.new_build_setting_condition(platforms = ["ios"]))]),
        dependencies = [pkginfos.new_target_dependency(product = pkginfos.new_product_reference("Helpers", "helpers"))],
    )
    entry = {"condition": "//:ios", "configurations": {"debug": "//:ios_debug", "fastbuild": "//:ios_fastbuild", "release": "//:ios_release"}, "environment": "simulator", "platform": "ios", "sdk": "iPhoneSimulator"}
    fields = structs.to_dict(pkg_ctxs.new(pkg_info = pkginfos.new(name = "Consumer", path = ".", targets = [target], dependencies = [pkginfos.new_dependency(identity = "helpers", name = "helpers")]), repo_name = "swiftpkg_consumer", system_sdk_deps = True))
    fields["sdk_modules"] = struct(
        modules = {"Foundation": ["iPhoneSimulator"], "Testing": ["iPhoneSimulator"]},
        conditions = {"iPhoneSimulator": entry},
        scan = {"defines": ["CUSTOM"], "developer_dir": "/Xcode/Developer", "sdks": {"iPhoneSimulator": "/SDK"}, "swiftc": "/Xcode/usr/bin/swiftc", "targets": {"iPhoneSimulator": "arm64-apple-ios17.0-simulator"}},
    )
    return struct(context = struct(**fields), target = target, entry = entry)

def _arguments_test(ctx):
    env = unittest.begin(ctx)
    fixture = _fixture()
    args = compiler_imports.arguments(fixture.context, fixture.target, fixture.entry, "debug", ["Testing"])
    asserts.equals(env, [
        "/Xcode/usr/bin/swiftc",
        "-frontend",
        "-scan-dependencies",
        "-import-prescan",
        "-module-name",
        "Consumer",
        "-sdk",
        "/SDK",
        "-target",
        "arm64-apple-ios17.0-simulator",
        "-module-cache-path",
        ".rspm_sdk_module_cache",
        "-DSWIFT_PACKAGE",
        "-Onone",
        "-DDEBUG",
        "-DCUSTOM",
        "-module-can-import",
        "Testing",
        "-DIOS_ONLY",
        "Sources/Consumer.swift",
    ], args)
    release = compiler_imports.arguments(fixture.context, fixture.target, fixture.entry, "release", [])
    asserts.true(env, "-DRELEASE_ONLY" in release)
    asserts.false(env, "-DDEBUG" in release)
    asserts.true(env, "-O" in release)
    return unittest.end(env)

arguments_test = unittest.make(_arguments_test)

def _prepare_test(ctx):
    env = unittest.begin(ctx)
    fixture = _fixture()
    reads = []
    calls = []
    outputs = {}

    def read(path):
        reads.append(str(path))
        if path == "repos.json":
            return json.encode({"repo_names": ["swiftpkg_helpers"]})
        if str(path).endswith("swiftpkg_helpers//:pkg_info.json"):
            return json.encode({"name": "Helpers", "products": [{"name": "Helpers", "targets": ["Testing"]}], "targets": [{"c99name": "Testing", "dependencies": [], "name": "Testing"}]})
        return "import Testing\nimport Foundation\n"

    # buildifier: disable=unused-variable
    def execute(args, environment):
        calls.append(args)
        asserts.true(env, "-module-can-import" in args)
        asserts.true(env, "Testing" in args)
        asserts.true(env, "/Developer/usr/lib" in args)
        asserts.true(env, "/SDK/Developer/Library/Frameworks" in args)
        return struct(return_code = 0, stdout = '{"imports": ["Testing", "Foundation"]}', stderr = "")

    repo = struct(
        name = "extension+swiftpkg_consumer",
        attr = struct(bazel_package_name = "swiftpkg_consumer", package_repos = "repos.json"),
        read = read,
        execute = execute,
        path = lambda p: struct(exists = True, is_dir = False, realpath = str(p), dirname = struct(dirname = "/Developer")),
        report_progress = lambda _: None,
        file = lambda p, contents: outputs.update({p: contents}),
    )
    result = sdk_inference_context.prepare(repo, fixture.context)
    asserts.equals(env, 1, len([p for p in reads if p.endswith("pkg_info.json")]))
    asserts.equals(env, ["Consumer", "Testing"], result.dependency_modules["Consumer"]["ios"])
    asserts.equals(env, 2, len(calls))  # debug and fastbuild reuse identical arguments
    asserts.equals(env, 3, len(result.source_scans["Consumer"]))
    report = json.decode(outputs["sdk_inference.json"])
    asserts.equals(env, ["Sources/Consumer.swift"], report["targets"]["Consumer"]["sources"])
    asserts.equals(env, result.source_scans["Consumer"], report["targets"]["Consumer"]["scans"])
    asserts.equals(env, ["Security"], report["targets"]["Consumer"]["linked_frameworks"][0]["values"])
    return unittest.end(env)

prepare_test = unittest.make(_prepare_test)

def compiler_imports_test_suite():
    unittest.suite("compiler_imports_tests", arguments_test, prepare_test)
