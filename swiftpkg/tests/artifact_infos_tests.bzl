"""Tests for `artifact_infos` module."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")

def _link_type_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

link_type_test = unittest.make(_link_type_test)

def artifact_infos_test_suite(name = "artifact_infos_tests"):
    return unittest.suite(
        name,
        link_type_test,
    )
