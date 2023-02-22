"""Tests for `objc_files` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:objc_files.bzl", "objc_files")

def _parse_for_imported_framework_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "no line",
            line = None,
            exp = None,
        ),
        struct(
            msg = "empty line",
            line = "",
            exp = None,
        ),
        struct(
            msg = "line with the word import",
            line = """\
  return @"this is not an import";
""",
            exp = None,
        ),
        struct(
            msg = "#import dir/header with brackets",
            line = """\
#import <CoreTelephony/CTCarrier.h>
""",
            exp = "CoreTelephony",
        ),
        struct(
            msg = "#import header with brackets",
            line = """\
#import <TargetConditionals.h>
""",
            exp = None,
        ),
        struct(
            msg = "#import dir/header with quotes",
            line = """\
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"
""",
            exp = None,
        ),
    ]
    for t in tests:
        # DEBUG BEGIN
        print("*** CHUCK =======")
        print("*** CHUCK t.msg: ", t.msg)

        # DEBUG END
        actual = objc_files.parse_for_imported_framework(t.line)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

parse_for_imported_framework_test = unittest.make(_parse_for_imported_framework_test)

def objc_files_test_suite():
    return unittest.suite(
        "objc_files_tests",
        parse_for_imported_framework_test,
    )
