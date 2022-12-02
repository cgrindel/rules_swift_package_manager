load("@bazel_skylib//lib:unittest.bzl", "unittest")

def _get_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

get_test = unittest.make(_get_test)

def package_infos_test_suite():
    return unittest.suite(
        "package_infos_tests",
        get_test,
    )
