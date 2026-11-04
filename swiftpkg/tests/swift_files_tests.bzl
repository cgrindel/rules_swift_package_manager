"""Tests for `swift_files` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:swift_files.bzl", "swift_files")

def _has_objc_directive_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "has @objc",
            contents = """\
@objc(OIFooSwiftVersionInfo)
public class FooSwiftVersionInfo: NSObject {
    @objc(myVersion) public func version() -> String {
        let verInfo = VersionInfo()
        return verInfo.version
    }
}
""",
            exp = True,
        ),
        struct(
            msg = "has @objcMembers",
            contents = """\
@objcMembers public class FooSwiftVersionInfo: NSObject {
    public func version() -> String {
        let verInfo = VersionInfo()
        return verInfo.version
    }
}
""",
            exp = True,
        ),
        struct(
            msg = "no directives",
            contents = """\
public class FooSwiftVersionInfo: NSObject {
    public func version() -> String {
        let verInfo = VersionInfo()
        return verInfo.version
    }
}
""",
            exp = False,
        ),
    ]
    for t in tests:
        actual = swift_files.has_objc_directive(t.contents)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

has_objc_directive_test = unittest.make(_has_objc_directive_test)

def _has_import_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "empty content",
            imp = "XCTest",
            content = "",
            exp = False,
        ),
        struct(
            msg = "single import",
            imp = "XCTest",
            content = """\
import XCTest
""",
            exp = True,
        ),
        struct(
            msg = "import at end of content",
            imp = "XCTest",
            content = "import XCTest",
            exp = True,
        ),
        struct(
            msg = "similar import, suffix differs",
            imp = "XCTest",
            content = "import XCTestOverlay",
            exp = False,
        ),
        struct(
            msg = "similar import, prefix differs",
            imp = "XCTest",
            content = "_import XCTest",
            exp = False,
        ),
        struct(
            msg = "multiple imports, keep looking",
            imp = "XCTest",
            content = """\
import XCTestOverlay
import XCTest
""",
            exp = True,
        ),
        struct(
            msg = "import inside a single-line comment",
            imp = "XCTest",
            content = """\
// import XCTest
""",
            exp = False,
        ),
        struct(
            msg = "import inside a multi-line comment",
            imp = "XCTest",
            content = """\
/* The following should be ignored:
import XCTest
*/
""",
            exp = False,
        ),
        struct(
            msg = "import inside a single-line string",
            imp = "XCTest",
            content = """\
let ignoreMe = " import XCTest "
""",
            exp = False,
        ),
        struct(
            msg = "import inside a multi-line string",
            imp = "XCTest",
            content = '''\
let ignoreMe = """
import XCTest
"""
''',
            exp = False,
        ),
        struct(
            msg = "invalid import and valid import",
            imp = "XCTest",
            content = """\
// import XCTest
import XCTest
""",
            exp = True,
        ),
        struct(
            msg = "inside conditional compilation",
            imp = "XCTest",
            content = """\
#if DEBUG
    #if !canImport(ObjectiveC)
      import Chicken
    #endif
    import XCTest
#endif
""",
            exp = False,
        ),
    ]
    for t in tests:
        actual = swift_files.has_import(t.content, t.imp)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

has_import_test = unittest.make(_has_import_test)

def _collect_imports_test(ctx):
    env = unittest.begin(ctx)
    content = '''\
// import FakeComment
/* nested /* import FakeNested */ import FakeBlock */
let text = "import FakeString"
let raw = ##"import FakeRaw"##
let multiline = """
import FakeMultiline
"""
let interpolated = "value \\(call("import FakeInterpolation"))"
let regex = #/import FakeRegex/#
let bare = /import FakeBare/
@_exported import Foundation
public import struct Darwin.stat
import /* module */ Dispatch
#if canImport(UIKit)
@preconcurrency import UIKit
#else
import AppKit
#endif
import Foundation.NSObject; import class Foundation.NSString
let `import` = 1
// comment at end without newline'''
    actual = swift_files.collect_imports(content)
    asserts.equals(env, ["Foundation", "Darwin", "Dispatch", "UIKit", "AppKit", "Foundation", "Foundation"], [i.module_name for i in actual])
    asserts.equals(env, [False, False, False, True, True, False, False], [i.is_conditional for i in actual])
    asserts.equals(env, [11, 12, 13, 15, 17, 19, 19], [i.line_number for i in actual])
    asserts.equals(env, ["Foundation"], [i.module_name for i in swift_files.collect_imports("import\nFoundation")])
    asserts.equals(env, [], swift_files.collect_imports("some.import Foundation"))
    return unittest.end(env)

collect_imports_test = unittest.make(_collect_imports_test)

def swift_files_test_suite():
    return unittest.suite(
        "swift_files_tests",
        has_objc_directive_test,
        has_import_test,
        collect_imports_test,
    )
