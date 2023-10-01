"""Tests for `objc_files` module."""

load("@bazel_skylib//lib:paths.bzl", "paths")
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
            msg = "#import dir/header with brackets, is framework",
            line = """\
#import <CoreTelephony/CTCarrier.h>
""",
            exp = "CoreTelephony",
        ),
        struct(
            msg = "#    import, the pound is not adjacent to import ",
            line = """\
#    import <SystemConfiguration/SystemConfiguration.h>
""",
            exp = "SystemConfiguration",
        ),
        struct(
            msg = "#import dir/header with brackets, is not framework",
            line = """\
#import <Foo/Foo.h>
""",
            exp = None,
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
        struct(
            msg = "@import, is framework",
            line = """\
@import UIKit;
""",
            exp = "UIKit",
        ),
        struct(
            msg = "@import, is not framework",
            line = """\
@import FirebaseCore;
""",
            exp = None,
        ),
    ]
    for t in tests:
        actual = objc_files.parse_for_imported_framework(t.line)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

parse_for_imported_framework_test = unittest.make(_parse_for_imported_framework_test)

def new_stub_repository_ctx(file_contents = {}):
    def read(path):
        return file_contents.get(path, "")

    return struct(
        read = read,
    )

def _collect_builtin_frameworks_test(ctx):
    env = unittest.begin(ctx)

    root_path = "/path/to/target"

    tests = [
        struct(
            msg = "target with #imports",
            srcs = ["Foo.h", "Foo.m", "Bar.h", "Bar.m"],
            file_contents = {
                "Bar.h": """\
#import <Foundation/Foundation.h>
""",
                "Foo.h": """\
#import <Foundation/Foundation.h>
#import <CoreTelephony/CTCarrier.h>
""",
            },
            exp = ["CoreTelephony", "Foundation"],
        ),
        struct(
            msg = "target with @imports",
            srcs = ["Foo.h", "Foo.m", "Bar.h", "Bar.m"],
            file_contents = {
                "Bar.h": """\
@import Foundation;
""",
                "Foo.h": """\
@import Foundation;
@import CoreTelephony;
""",
            },
            exp = ["CoreTelephony", "Foundation"],
        ),
    ]
    for t in tests:
        stub_repository_ctx = new_stub_repository_ctx(
            file_contents = {
                paths.normalize(paths.join(root_path, fname)): cnts
                for fname, cnts in getattr(t, "file_contents", {}).items()
            },
        )
        actual = objc_files.collect_builtin_frameworks(
            repository_ctx = stub_repository_ctx,
            root_path = root_path,
            srcs = t.srcs,
        )
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

collect_builtin_frameworks_test = unittest.make(_collect_builtin_frameworks_test)

def _has_objc_srcs_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "has entries",
            srcs = [],
            exp = False,
        ),
        struct(
            msg = "has .m file",
            srcs = ["foo.h", "foo.m"],
            exp = True,
        ),
        struct(
            msg = "has .mm file",
            srcs = ["foo.h", "foo.mm"],
            exp = True,
        ),
        struct(
            msg = "has no objc srcs",
            srcs = ["foo.h", "foo.c"],
            exp = False,
        ),
    ]
    for t in tests:
        actual = objc_files.has_objc_srcs(t.srcs)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

has_objc_srcs_test = unittest.make(_has_objc_srcs_test)

def objc_files_test_suite():
    return unittest.suite(
        "objc_files_tests",
        parse_for_imported_framework_test,
        collect_builtin_frameworks_test,
        has_objc_srcs_test,
    )
