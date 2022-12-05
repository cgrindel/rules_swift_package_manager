load("@bazel_skylib//lib:unittest.bzl", "unittest")

def _from_url_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

from_url_test = unittest.make(_from_url_test)

def bazel_repo_names_test_suite():
    return unittest.suite(
        "bazel_repo_names_tests",
        from_url_test,
    )
