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
            msg = "inside DEBUG conditional compilation",
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
        struct(
            msg = "inside non-DEBUG conditional compilation",
            imp = "XCTest",
            content = """\
#if !os(watchOS)
    import XCTest
#endif
""",
            exp = True,
        ),
        struct(
            msg = "inside multi-level non-DEBUG conditional compilation",
            imp = "XCTest",
            content = """\
#if !os(watchOS)
    #if DEBUG
        import XCTest
    #endif
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

def swift_files_test_suite():
    return unittest.suite(
        "swift_files_tests",
        has_objc_directive_test,
        has_import_test,
    )
