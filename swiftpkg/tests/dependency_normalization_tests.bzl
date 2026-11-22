"""SDK dependency normalization: label identity and actual select resolution."""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")
load("//swiftpkg/internal:dependency_normalization.bzl", "dependency_normalization")
load("//swiftpkg/internal:starlark_codegen.bzl", scg = "starlark_codegen")
load("//swiftpkg/internal:system_sdk_labels.bzl", "system_sdk_labels")

def _normalization_test(ctx):
    env = unittest.begin(ctx)
    apparent = "@system_sdk//:Foundation"
    canonical = system_sdk_labels.key(apparent)

    # A later append must not duplicate the inferred dependency.
    select = scg.new_fn_call("select", {"//:ios": ["@system_sdk//:Foundation"], "//conditions:default": []})
    value = scg.new_expr(select, scg.new_op("+"), ["@system_sdk//:Foundation"])
    normalized = dependency_normalization.normalize(value, "test_")
    asserts.equals(env, '["@system_sdk//:Foundation"]', scg.to_starlark(normalized.value))

    # Two conditional occurrences preserve exclusion branches and nonempty defaults.
    first = scg.new_fn_call("select", {"//:broad": ["//:dep"], "//:specialized": [], "//conditions:default": []})
    second = scg.new_fn_call("select", {"//:other": [], "//conditions:default": ["//:dep"]})
    normalized = dependency_normalization.normalize(scg.new_expr(first, scg.new_op("+"), second), "test_", sdk_labels = ["//:dep"])
    aliases = [h for h in normalized.helpers if h.kind == "alias"]
    asserts.equals(env, 2, len(aliases))
    asserts.equals(env, {"//:broad": ":test_true", "//:specialized": ":test_false", "//conditions:default": ":test_false"}, aliases[0].attrs["actual"].args[0])
    asserts.equals(env, {"//:other": ":test_false", "//conditions:default": ":test_true"}, aliases[1].attrs["actual"].args[0])
    asserts.equals(env, 1, scg.to_starlark(normalized.value).count("//:dep"))

    # Add overrides can spell the SDK repo differently from inferred deps.
    for first, second in [(apparent, canonical), (canonical, apparent)]:
        conditional = scg.new_fn_call("select", {"//:ios": [first], "//conditions:default": []})
        result = dependency_normalization.normalize(scg.new_expr(conditional, scg.new_op("+"), [second]), "identity_")
        asserts.equals(env, '["' + first + '"]', scg.to_starlark(result.value))
        result = dependency_normalization.normalize([first, second], "identity_")
        asserts.equals(env, '["' + first + '"]', scg.to_starlark(result.value))

    # Leave unrelated deps, their spelling, duplicates and ordering untouched.
    unrelated = scg.new_expr([":local", "//:local"], scg.new_op("+"), [":local"])
    asserts.equals(env, unrelated, dependency_normalization.normalize(unrelated, "identity_").value)
    mixed = [":local", ":local", apparent, canonical]
    result = dependency_normalization.normalize(mixed, "identity_")
    asserts.equals(env, [":local", ":local", apparent], result.value.members[0])
    return unittest.end(env)

normalization_test = unittest.make(_normalization_test)

def _resolved_deps_test(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.equals(env, ctx.attr.expected, len(target[DefaultInfo].files.to_list()))
    return analysistest.end(env)

def _settings(broad = False, narrow = False, other = False):
    return {
        str(Label("//swiftpkg/tests:normalization_broad_flag")): broad,
        str(Label("//swiftpkg/tests:normalization_narrow_flag")): narrow,
        str(Label("//swiftpkg/tests:normalization_other_flag")): other,
    }

_default_deps_test = analysistest.make(_resolved_deps_test, attrs = {"expected": attr.int()}, config_settings = _settings())
_overlap_deps_test = analysistest.make(_resolved_deps_test, attrs = {"expected": attr.int()}, config_settings = _settings(broad = True))
_broad_deps_test = analysistest.make(_resolved_deps_test, attrs = {"expected": attr.int()}, config_settings = _settings(broad = True, other = True))
_specialized_deps_test = analysistest.make(_resolved_deps_test, attrs = {"expected": attr.int()}, config_settings = _settings(broad = True, narrow = True, other = True))

def _as_selector(value):
    return select(value.args[0]) if getattr(value, "fn_name", None) == "select" else value

def _normalization_targets():
    for flag in ["broad", "narrow", "other"]:
        bool_flag(name = "normalization_" + flag + "_flag", build_setting_default = False)
    native.config_setting(name = "normalization_broad", flag_values = {":normalization_broad_flag": "true"})
    native.config_setting(name = "normalization_narrow", flag_values = {":normalization_broad_flag": "true", ":normalization_narrow_flag": "true"})
    native.config_setting(name = "normalization_other", flag_values = {":normalization_other_flag": "true"})
    native.filegroup(name = "normalization_payload", srcs = ["dependency_normalization_tests.bzl"])
    first = scg.new_fn_call("select", {":normalization_broad": [":normalization_payload"], ":normalization_narrow": [], "//conditions:default": []})
    second = scg.new_fn_call("select", {":normalization_other": [], "//conditions:default": [":normalization_payload"]})
    result = dependency_normalization.normalize(scg.new_expr(first, scg.new_op("+"), second), "normalization_", sdk_labels = [":normalization_payload"])
    for helper in result.helpers:
        if helper.kind == "alias":
            native.alias(name = helper.name, actual = _as_selector(helper.attrs["actual"]))
        elif helper.kind == "config_setting":
            native.config_setting(name = helper.name, **helper.attrs)
        else:
            selects.config_setting_group(name = helper.name, **helper.attrs)
    srcs = []
    for part in result.value.members:
        if getattr(part, "operator", None) != "+":
            srcs = srcs + _as_selector(part)
    native.filegroup(name = "normalized_dependencies", srcs = srcs)
    tests = []
    for name, rule, expected in [
        ("default", _default_deps_test, 1),
        ("overlap", _overlap_deps_test, 1),
        ("broad", _broad_deps_test, 1),
        ("specialized", _specialized_deps_test, 0),
    ]:
        test_name = "normalization_" + name + "_test"
        rule(name = test_name, target_under_test = ":normalized_dependencies", expected = expected)
        tests.append(":" + test_name)
    return tests

def dependency_normalization_test_suite(name = "dependency_normalization_tests"):
    unittest.suite("dependency_normalization_unit_tests", normalization_test)
    native.test_suite(name = name, tests = [":dependency_normalization_unit_tests"] + _normalization_targets())
