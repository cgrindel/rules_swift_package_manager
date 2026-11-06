"""Swift import scanner tests."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:swift_imports.bzl", "swift_imports")

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
    actual = swift_imports.collect(content)
    asserts.equals(env, ["Foundation", "Darwin", "Dispatch", "UIKit", "AppKit", "Foundation", "Foundation"], [i.module_name for i in actual])
    asserts.equals(env, [False, False, False, True, True, False, False], [i.is_conditional for i in actual])
    asserts.equals(env, [11, 12, 13, 15, 17, 19, 19], [i.line_number for i in actual])
    asserts.equals(env, ["Foundation"], [i.module_name for i in swift_imports.collect("import\nFoundation")])
    asserts.equals(env, [], swift_imports.collect("some.import Foundation"))
    asserts.equals(env, "import Foundation\n", swift_imports.scan_prefix("import Foundation\nlet longBody = 1\n"))
    return unittest.end(env)

collect_imports_test = unittest.make(_collect_imports_test)

def swift_imports_test_suite():
    unittest.suite("swift_imports_tests", collect_imports_test)
