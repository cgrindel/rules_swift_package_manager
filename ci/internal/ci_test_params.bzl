"""Module for creating test parameters."""

load(":providers.bzl", "CITestParamsInfo")

def _new_integration_test_params(test, os, bzlmod_mode):
    return struct(
        test = str(test),
        os = os,
        bzlmod_mode = bzlmod_mode,
    )

def _collect_from_deps(deps):
    itp_depsets = []
    for dep in deps:
        if CITestParamsInfo in dep:
            itp_depsets.append(dep[CITestParamsInfo].integration_test_params)
    return depset([], transitive = itp_depsets)

def _sort_integration_test_params(itps):
    return sorted(
        itps,
        key = lambda itp: "{test}_{os}_{bzlmod_mode}".format(
            test = itp.test,
            os = itp.os,
            bzlmod_mode = itp.bzlmod_mode,
        ),
    )

ci_test_params = struct(
    new_integration_test_params = _new_integration_test_params,
    collect_from_deps = _collect_from_deps,
    sort_integration_test_params = _sort_integration_test_params,
)
