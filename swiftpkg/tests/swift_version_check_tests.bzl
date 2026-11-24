"""Analysis tests for `swift_version_check`."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

_MODE_FLAG = str(Label("//:swift_version_check"))

def _validation_files(env):
    target = analysistest.target_under_test(env)
    return target[OutputGroupInfo]._validation.to_list()

def _off_mode_writes_marker_without_action_test_impl(ctx):
    env = analysistest.begin(ctx)

    actions = analysistest.target_actions(env)
    asserts.equals(
        env,
        ["FileWrite"],
        [a.mnemonic for a in actions],
    )

    validation_files = _validation_files(env)
    asserts.equals(env, 1, len(validation_files))
    asserts.equals(
        env,
        "swift_version_check_fixture.validated",
        validation_files[0].basename,
    )
    asserts.equals(
        env,
        [validation_files[0]],
        actions[0].outputs.to_list(),
    )

    return analysistest.end(env)

_off_mode_writes_marker_without_action_test = analysistest.make(
    _off_mode_writes_marker_without_action_test_impl,
    config_settings = {_MODE_FLAG: "off"},
)

def _error_mode_registers_check_action_test_impl(ctx):
    env = analysistest.begin(ctx)

    actions = analysistest.target_actions(env)
    asserts.equals(
        env,
        ["SwiftVersionCheck"],
        [a.mnemonic for a in actions],
    )
    action = actions[0]

    inputs = action.inputs.to_list()
    version_files = [f for f in inputs if f.basename == "swift_version.txt"]
    asserts.equals(env, 1, len(version_files), "inputs: {}".format(inputs))
    scripts = [f for f in inputs if f.basename == "swift_version_check.sh"]
    asserts.equals(env, 1, len(scripts), "inputs: {}".format(inputs))
    wrappers = [f for f in inputs if f.short_path.endswith("tools/swift")]
    asserts.equals(env, 1, len(wrappers), "inputs: {}".format(inputs))

    validation_files = _validation_files(env)
    asserts.equals(
        env,
        [
            scripts[0].path,
            wrappers[0].path,
            version_files[0].path,
            "swift/macos",
            validation_files[0].path,
        ],
        action.argv[-5:],
    )

    validation_files = _validation_files(env)
    asserts.equals(env, 1, len(validation_files))
    asserts.equals(env, validation_files, action.outputs.to_list())

    return analysistest.end(env)

_error_mode_registers_check_action_test = analysistest.make(
    _error_mode_registers_check_action_test_impl,
    config_settings = {_MODE_FLAG: "error"},
)

def swift_version_check_test_suite(name = "swift_version_check_tests"):
    """Declares the `swift_version_check` analysis tests.

    Args:
        name: The name of the test suite.
    """
    target_under_test = ":swift_version_check_fixture"
    _off_mode_writes_marker_without_action_test(
        name = "off_mode_writes_marker_without_action_test",
        target_under_test = target_under_test,
    )
    _error_mode_registers_check_action_test(
        name = "error_mode_registers_check_action_test",
        target_under_test = target_under_test,
    )
    native.test_suite(
        name = name,
        tests = [
            ":error_mode_registers_check_action_test",
            ":off_mode_writes_marker_without_action_test",
        ],
    )
