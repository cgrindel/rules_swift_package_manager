"""Module for creating test parameters."""

load(":providers.bzl", "CITestParamsInfo")

def _label_str(label):
    # Because we support running with bzlmod enabled and disabled, we need to
    # normalize the target value that is stored. We have chosen to use the
    # bzlmod version.
    result = str(label)
    if result.startswith("@@"):
        pass
    elif result.startswith("@"):
        result = "@{}".format(result)
    else:
        result = "@@{}".format(result)
    return result

def _new_integration_test_params(test, os, bzlmod_mode):
    return struct(
        test = _label_str(test),
        os = os,
        bzlmod_mode = bzlmod_mode,
    )

def _collect_from_deps(deps):
    itp_depsets = []
    for dep in deps:
        if CITestParamsInfo in dep:
            itp_depsets.append(dep[CITestParamsInfo].integration_test_params)
    return CITestParamsInfo(
        integration_test_params = depset([], transitive = itp_depsets),
    )

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
    label_str = _label_str,
    new_integration_test_params = _new_integration_test_params,
    collect_from_deps = _collect_from_deps,
    sort_integration_test_params = _sort_integration_test_params,
)
