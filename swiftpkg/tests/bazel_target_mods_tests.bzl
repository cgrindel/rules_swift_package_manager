"""Tests for `bazel_target_mods` API"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:bazel_target_mods.bzl", "bazel_target_mods")
load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load("//swiftpkg/internal:bzl_selects.bzl", "bzl_selects")
load("//swiftpkg/internal:starlark_codegen.bzl", scg = "starlark_codegen")

_verbs = bazel_target_mods.verbs

_impl_target = "Bar.rspm.__impl"
_impl_label = "@swiftpkg_foo//:Bar.rspm.__impl"

def _decl(attrs = {}):
    return build_decls.new(
        kind = "swift_library",
        name = _impl_target,
        attrs = attrs,
    )

def _attrs_after(decl, mods):
    decls = bazel_target_mods.apply([decl], mods)
    asserts_len = len(decls)
    if asserts_len != 1:
        fail("Expected a single declaration, but found {}.".format(asserts_len))
    return decls[0].attrs

def _starlark_for(attrs, attr_name):
    return scg.to_starlark(scg.new_expr(attrs[attr_name]))

# MARK: - Value Parsing

def _parse_value_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(msg = "true", value = "True", exp = True),
        struct(msg = "lowercase true", value = "true", exp = True),
        struct(msg = "mixed-case true", value = "TrUe", exp = True),
        struct(msg = "false", value = "False", exp = False),
        struct(msg = "lowercase false", value = "false", exp = False),
        struct(msg = "int", value = "42", exp = 42),
        struct(msg = "zero", value = "0", exp = 0),
        struct(msg = "negative int", value = "-13", exp = -13),
        struct(msg = "leading zeros", value = "007", exp = 7),
        struct(msg = "string", value = "-DFOO", exp = "-DFOO"),
        struct(msg = "empty string", value = "", exp = ""),
        struct(msg = "lone dash", value = "-", exp = "-"),
        struct(msg = "float-ish", value = "1.5", exp = "1.5"),
        struct(msg = "trailing space", value = "42 ", exp = "42 "),
        struct(msg = "truthy word", value = "yes", exp = "yes"),
    ]
    for t in tests:
        actual = bazel_target_mods.parse_value(t.value)
        asserts.equals(env, t.exp, actual, t.msg)
        asserts.equals(env, type(t.exp), type(actual), t.msg + " (type)")

    return unittest.end(env)

parse_value_test = unittest.make(_parse_value_test)

# MARK: - Target Label Parsing

def _parse_target_test(ctx):
    env = unittest.begin(ctx)

    parsed = bazel_target_mods.parse_target(_impl_label)
    asserts.equals(env, None, parsed.error)
    asserts.equals(env, "swiftpkg_foo", parsed.repo_name)
    asserts.equals(env, _impl_target, parsed.name)

    parsed = bazel_target_mods.parse_target("@@swiftpkg_foo//:Bar.rspm")
    asserts.equals(env, None, parsed.error)
    asserts.equals(env, "swiftpkg_foo", parsed.repo_name)
    asserts.equals(env, "Bar.rspm", parsed.name)

    failures = [
        struct(msg = "no repository", target = "//:Bar.rspm"),
        struct(msg = "no package separator", target = "@swiftpkg_foo:Bar"),
        struct(msg = "no target separator", target = "@swiftpkg_foo//Bar"),
        struct(msg = "empty repository", target = "@//:Bar.rspm"),
        struct(msg = "empty target", target = "@swiftpkg_foo//:"),
        struct(
            msg = "sub-package",
            target = "@swiftpkg_foo//Sources:Bar.rspm",
        ),
    ]
    for t in failures:
        parsed = bazel_target_mods.parse_target(t.target)
        asserts.true(
            env,
            parsed.error != None,
            "Expected an error for {}.".format(t.msg),
        )
        asserts.equals(env, None, parsed.repo_name, t.msg)
        asserts.equals(env, None, parsed.name, t.msg)

    # The sub-package error should explain what went wrong.
    parsed = bazel_target_mods.parse_target("@swiftpkg_foo//Sources:Bar.rspm")
    asserts.true(
        env,
        parsed.error.find("root package") > -1,
        "Expected the sub-package error to mention the root package.",
    )

    return unittest.end(env)

parse_target_test = unittest.make(_parse_target_test)

# MARK: - Condition Canonicalization

def _canonicalize_condition_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "main repository relative",
            condition = "//:release_build",
            exp = "@@//:release_build",
        ),
        struct(
            msg = "main repository relative with package",
            condition = "//some/pkg:setting",
            exp = "@@//some/pkg:setting",
        ),
        struct(
            msg = "already canonical",
            condition = "@@rules_swift_package_manager+//:setting",
            exp = "@@rules_swift_package_manager+//:setting",
        ),
        struct(
            msg = "the default condition is a pseudo-label",
            condition = "//conditions:default",
            exp = "//conditions:default",
        ),
        struct(
            msg = "the canonical default condition is normalized",
            condition = "@@//conditions:default",
            exp = "//conditions:default",
        ),
    ]
    for t in tests:
        asserts.equals(env, None, bazel_target_mods.condition_error(t.condition), t.msg)
        asserts.equals(
            env,
            t.exp,
            bazel_target_mods.canonicalize_condition(t.condition),
            t.msg,
        )

    # An apparent repository name (a single `@`) would be resolved using the
    # repository mapping of the generated repository, not the root module's.
    error = bazel_target_mods.condition_error("@some_repo//:setting")
    asserts.true(
        env,
        error != None,
        "Expected an apparent repository name to be rejected.",
    )
    asserts.true(
        env,
        error.find("@some_repo//:setting") > -1,
        "Expected the error to name the condition.",
    )
    asserts.true(
        env,
        error.find("@@") > -1,
        "Expected the error to suggest a canonical label.",
    )

    # A relative or otherwise non-absolute label is rejected, too.
    for condition in ["release_build", ":release_build", "conditions:default"]:
        asserts.true(
            env,
            bazel_target_mods.condition_error(condition) != None,
            "Expected '{}' to be rejected.".format(condition),
        )

    return unittest.end(env)

canonicalize_condition_test = unittest.make(_canonicalize_condition_test)

# MARK: - Modification Construction

def _new_error_test(ctx):
    env = unittest.begin(ctx)

    # Well-formed modifications.
    asserts.equals(
        env,
        None,
        bazel_target_mods.new_error(
            _verbs.set,
            _impl_target,
            "alwayslink",
            value = "False",
        ),
    )
    asserts.equals(
        env,
        None,
        bazel_target_mods.new_error(
            _verbs.add,
            _impl_target,
            "copts",
            values = ["-DFOO"],
        ),
    )
    asserts.equals(
        env,
        None,
        bazel_target_mods.new_error(
            _verbs.add_select,
            _impl_target,
            "copts",
            values = {"//:a": ["-DA"]},
        ),
    )

    # The `name` attribute is emitted from the declaration name, so modifying
    # it would render a duplicate `name` keyword.
    for verb in _verbs.all:
        error = bazel_target_mods.new_error(
            verb,
            _impl_target,
            "name",
            value = "Other",
            values = {"//:a": ["-DA"]} if verb.endswith("select") else ["-DA"],
        )
        asserts.true(
            env,
            error != None,
            "Expected the `name` attribute to be rejected for '{}'.".format(verb),
        )
        asserts.true(
            env,
            error.find("`name`") > -1,
            "Expected the error to name the `name` attribute.",
        )

    # An `add` with no values would create an empty attribute.
    for values in [[], None]:
        error = bazel_target_mods.new_error(
            _verbs.add,
            _impl_target,
            "copts",
            values = values,
        )
        asserts.true(
            env,
            error != None,
            "Expected empty `add` values to be rejected.",
        )
        asserts.true(
            env,
            error.find("at least one value") > -1,
            "Expected the error to require at least one value.",
        )

    # The `select` verbs require at least one condition.
    for verb in [_verbs.set_select, _verbs.add_select]:
        for values in [{}, None]:
            asserts.true(
                env,
                bazel_target_mods.new_error(
                    verb,
                    _impl_target,
                    "copts",
                    values = values,
                ) != None,
                "Expected empty `{}` values to be rejected.".format(verb),
            )

    # Other malformed inputs.
    asserts.true(
        env,
        bazel_target_mods.new_error("nope", _impl_target, "copts", value = "-DA") != None,
        "Expected an unrecognized verb to be rejected.",
    )
    asserts.true(
        env,
        bazel_target_mods.new_error(_verbs.set, "", "copts", value = "-DA") != None,
        "Expected an empty target to be rejected.",
    )
    asserts.true(
        env,
        bazel_target_mods.new_error(_verbs.set, _impl_target, "", value = "-DA") != None,
        "Expected an empty attribute to be rejected.",
    )
    asserts.true(
        env,
        bazel_target_mods.new_error(_verbs.set, _impl_target, "copts") != None,
        "Expected a missing `set` value to be rejected.",
    )

    return unittest.end(env)

new_error_test = unittest.make(_new_error_test)

# MARK: - JSON Round Trip

def _encode_decode_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, "", bazel_target_mods.encode([]))
    asserts.equals(env, [], bazel_target_mods.decode(""))

    mods = [
        bazel_target_mods.new(
            _verbs.set,
            _impl_target,
            "alwayslink",
            value = "False",
        ),
        bazel_target_mods.new(
            _verbs.add,
            _impl_target,
            "copts",
            values = ["-DFOO", "-DBAR"],
        ),
        bazel_target_mods.new(
            _verbs.set_select,
            _impl_target,
            "defines",
            values = {"//:release_build": ["NDEBUG"]},
        ),
        bazel_target_mods.new(
            _verbs.add_select,
            _impl_target,
            "copts",
            values = {"//:release_build": ["-O2"]},
        ),
    ]
    encoded = bazel_target_mods.encode(mods)
    asserts.true(env, encoded != "", "Expected a non-empty JSON string.")
    asserts.equals(env, mods, bazel_target_mods.decode(encoded))

    # The select conditions are canonicalized when the modification is created,
    # so the decoded values are ready to be written into an external repository.
    asserts.equals(
        env,
        {"@@//:release_build": ["NDEBUG"]},
        bazel_target_mods.decode(encoded)[2]["values"],
    )

    return unittest.end(env)

encode_decode_test = unittest.make(_encode_decode_test)

# MARK: - set

def _set_test(ctx):
    env = unittest.begin(ctx)

    # Replaces an existing scalar attribute.
    attrs = _attrs_after(
        _decl({"alwayslink": True}),
        [bazel_target_mods.new(_verbs.set, _impl_target, "alwayslink", value = "False")],
    )
    asserts.equals(env, False, attrs["alwayslink"])

    # Creates an absent attribute.
    attrs = _attrs_after(
        _decl(),
        [bazel_target_mods.new(_verbs.set, _impl_target, "alwayslink", value = "True")],
    )
    asserts.equals(env, True, attrs["alwayslink"])

    # Replaces a list attribute wholesale.
    attrs = _attrs_after(
        _decl({"copts": ["-DGENERATED"]}),
        [bazel_target_mods.new(_verbs.set, _impl_target, "copts", value = "-DONLY")],
    )
    asserts.equals(env, "-DONLY", attrs["copts"])

    # Replaces an expression-valued attribute.
    generated = bzl_selects.to_starlark([
        "-DGENERATED",
        bzl_selects.new(value = "-DCOND", condition = "//:cond"),
    ])
    attrs = _attrs_after(
        _decl({"copts": generated}),
        [bazel_target_mods.new(_verbs.set, _impl_target, "copts", value = "7")],
    )
    asserts.equals(env, 7, attrs["copts"])

    return unittest.end(env)

set_test = unittest.make(_set_test)

# MARK: - add

def _add_test(ctx):
    env = unittest.begin(ctx)

    # Appends to a plain list attribute.
    attrs = _attrs_after(
        _decl({"copts": ["-DGENERATED"]}),
        [bazel_target_mods.new(
            _verbs.add,
            _impl_target,
            "copts",
            values = ["-DFOO", "-DBAR"],
        )],
    )
    asserts.equals(env, ["-DGENERATED", "-DFOO", "-DBAR"], attrs["copts"])

    # Creates an absent attribute.
    attrs = _attrs_after(
        _decl(),
        [bazel_target_mods.new(
            _verbs.add,
            _impl_target,
            "copts",
            values = ["-DFOO"],
        )],
    )
    asserts.equals(env, ["-DFOO"], attrs["copts"])

    # Composes with a scalar attribute. Bazel reports the type error when the
    # generated file is loaded.
    attrs = _attrs_after(
        _decl({"alwayslink": True}),
        [bazel_target_mods.new(
            _verbs.add,
            _impl_target,
            "alwayslink",
            values = ["-DFOO"],
        )],
    )
    asserts.equals(env, "True + [\"-DFOO\"]", _starlark_for(attrs, "alwayslink"))

    # Composes with an expression-valued attribute, staying last.
    generated = bzl_selects.to_starlark([
        "-DGENERATED",
        bzl_selects.new(value = "-DCOND", condition = "//:cond"),
    ])
    attrs = _attrs_after(
        _decl({"copts": generated}),
        [bazel_target_mods.new(
            _verbs.add,
            _impl_target,
            "copts",
            values = ["-DFOO"],
        )],
    )
    asserts.equals(
        env,
        """\
["-DGENERATED"] + select({
    "//:cond": ["-DCOND"],
    "//conditions:default": [],
}) + ["-DFOO"]\
""",
        _starlark_for(attrs, "copts"),
    )

    return unittest.end(env)

add_test = unittest.make(_add_test)

# MARK: - set_select

def _set_select_test(ctx):
    env = unittest.begin(ctx)

    mod = bazel_target_mods.new(
        _verbs.set_select,
        _impl_target,
        "copts",
        values = {
            "//:release_build": ["-DFOO"],
            "//conditions:default": [],
        },
    )

    # Replaces an existing list attribute. No default branch is added, and a
    # user-supplied default branch is kept last.
    attrs = _attrs_after(_decl({"copts": ["-DGENERATED"]}), [mod])
    asserts.equals(
        env,
        """\
select({
    "@@//:release_build": ["-DFOO"],
    "//conditions:default": [],
})\
""",
        _starlark_for(attrs, "copts"),
    )

    # Without a default branch, none is added.
    mod = bazel_target_mods.new(
        _verbs.set_select,
        _impl_target,
        "copts",
        values = {"//:release_build": ["-DFOO"]},
    )
    attrs = _attrs_after(_decl(), [mod])
    asserts.equals(
        env,
        """\
select({
    "@@//:release_build": ["-DFOO"],
})\
""",
        _starlark_for(attrs, "copts"),
    )

    # Replaces an expression-valued attribute.
    generated = bzl_selects.to_starlark([
        "-DGENERATED",
        bzl_selects.new(value = "-DCOND", condition = "//:cond"),
    ])
    attrs = _attrs_after(_decl({"copts": generated}), [mod])
    asserts.equals(
        env,
        """\
select({
    "@@//:release_build": ["-DFOO"],
})\
""",
        _starlark_for(attrs, "copts"),
    )

    # The canonical spelling of the default branch is normalized, so it is
    # recognized as the default branch and stays last.
    mod = bazel_target_mods.new(
        _verbs.set_select,
        _impl_target,
        "copts",
        values = {
            "//:release_build": ["-DFOO"],
            "@@//conditions:default": ["-DDEFAULT"],
        },
    )
    attrs = _attrs_after(_decl(), [mod])
    asserts.equals(
        env,
        """\
select({
    "@@//:release_build": ["-DFOO"],
    "//conditions:default": ["-DDEFAULT"],
})\
""",
        _starlark_for(attrs, "copts"),
    )

    return unittest.end(env)

set_select_test = unittest.make(_set_select_test)

# MARK: - add_select

def _add_select_test(ctx):
    env = unittest.begin(ctx)

    mod = bazel_target_mods.new(
        _verbs.add_select,
        _impl_target,
        "copts",
        values = {"//:release_build": ["-DFOO"]},
    )

    # Appended after a plain list attribute, with a default branch added.
    attrs = _attrs_after(_decl({"copts": ["-DGENERATED"]}), [mod])
    asserts.equals(
        env,
        """\
["-DGENERATED"] + select({
    "@@//:release_build": ["-DFOO"],
    "//conditions:default": [],
})\
""",
        _starlark_for(attrs, "copts"),
    )

    # Created when the attribute is absent.
    attrs = _attrs_after(_decl(), [mod])
    asserts.equals(
        env,
        """\
select({
    "@@//:release_build": ["-DFOO"],
    "//conditions:default": [],
})\
""",
        _starlark_for(attrs, "copts"),
    )

    # Appended after an expression-valued attribute.
    generated = bzl_selects.to_starlark([
        "-DGENERATED",
        bzl_selects.new(value = "-DCOND", condition = "//:cond"),
    ])
    attrs = _attrs_after(_decl({"copts": generated}), [mod])
    asserts.equals(
        env,
        """\
["-DGENERATED"] + select({
    "//:cond": ["-DCOND"],
    "//conditions:default": [],
}) + select({
    "@@//:release_build": ["-DFOO"],
    "//conditions:default": [],
})\
""",
        _starlark_for(attrs, "copts"),
    )

    # A user-supplied default branch is not replaced.
    mod = bazel_target_mods.new(
        _verbs.add_select,
        _impl_target,
        "copts",
        values = {
            "//:release_build": ["-DFOO"],
            "//conditions:default": ["-DDEFAULT"],
        },
    )
    attrs = _attrs_after(_decl(), [mod])
    asserts.equals(
        env,
        """\
select({
    "@@//:release_build": ["-DFOO"],
    "//conditions:default": ["-DDEFAULT"],
})\
""",
        _starlark_for(attrs, "copts"),
    )

    # The canonical spelling of the default branch is normalized, so a second
    # default branch is not appended.
    mod = bazel_target_mods.new(
        _verbs.add_select,
        _impl_target,
        "copts",
        values = {
            "//:release_build": ["-DFOO"],
            "@@//conditions:default": ["-DDEFAULT"],
        },
    )
    attrs = _attrs_after(_decl(), [mod])
    asserts.equals(
        env,
        """\
select({
    "@@//:release_build": ["-DFOO"],
    "//conditions:default": ["-DDEFAULT"],
})\
""",
        _starlark_for(attrs, "copts"),
    )

    return unittest.end(env)

add_select_test = unittest.make(_add_select_test)

# MARK: - Ordering

def _ordering_test(ctx):
    env = unittest.begin(ctx)

    # The declaration order below is deliberately shuffled. Whatever the order,
    # the setter runs first, then the `add` tags in declaration order, then the
    # `add_select` tags in declaration order.
    mods = [
        bazel_target_mods.new(
            _verbs.add,
            _impl_target,
            "copts",
            values = ["-DFIRST"],
        ),
        bazel_target_mods.new(
            _verbs.add_select,
            _impl_target,
            "copts",
            values = {"//:a": ["-DA"]},
        ),
        bazel_target_mods.new(
            _verbs.set,
            _impl_target,
            "copts",
            value = "-DONLY",
        ),
        bazel_target_mods.new(
            _verbs.add,
            _impl_target,
            "copts",
            values = ["-DSECOND"],
        ),
        bazel_target_mods.new(
            _verbs.add_select,
            _impl_target,
            "copts",
            values = {"//:b": ["-DB"]},
        ),
    ]
    asserts.equals(
        env,
        [_verbs.set, _verbs.add, _verbs.add, _verbs.add_select, _verbs.add_select],
        [m["verb"] for m in bazel_target_mods.ordered_mods(mods)],
    )

    attrs = _attrs_after(_decl({"copts": ["-DGENERATED"]}), mods)
    asserts.equals(
        env,
        """\
"-DONLY" + ["-DFIRST"] + ["-DSECOND"] + select({
    "@@//:a": ["-DA"],
    "//conditions:default": [],
}) + select({
    "@@//:b": ["-DB"],
    "//conditions:default": [],
})\
""",
        _starlark_for(attrs, "copts"),
    )

    return unittest.end(env)

ordering_test = unittest.make(_ordering_test)

# MARK: - Validation

def _validation_error_test(ctx):
    env = unittest.begin(ctx)

    set_mod = bazel_target_mods.new(
        _verbs.set,
        _impl_target,
        "copts",
        value = "-DONLY",
    )
    set_select_mod = bazel_target_mods.new(
        _verbs.set_select,
        _impl_target,
        "copts",
        values = {"//:a": ["-DA"]},
    )
    add_mod = bazel_target_mods.new(
        _verbs.add,
        _impl_target,
        "copts",
        values = ["-DFOO"],
    )
    other_attr_set_mod = bazel_target_mods.new(
        _verbs.set,
        _impl_target,
        "alwayslink",
        value = "False",
    )
    other_target_set_mod = bazel_target_mods.new(
        _verbs.set,
        "Baz.rspm.__impl",
        "copts",
        value = "-DONLY",
    )

    asserts.equals(env, None, bazel_target_mods.validation_error([]))
    asserts.equals(
        env,
        None,
        bazel_target_mods.validation_error([set_mod, add_mod, add_mod]),
        "One setter plus any number of adds is fine.",
    )
    asserts.equals(
        env,
        None,
        bazel_target_mods.validation_error(
            [set_mod, other_attr_set_mod, other_target_set_mod],
        ),
        "Setters for different attributes and targets do not conflict.",
    )

    for mods in [
        [set_mod, set_mod],
        [set_select_mod, set_select_mod],
        [set_mod, set_select_mod],
        [set_mod, add_mod, set_select_mod],
    ]:
        error = bazel_target_mods.validation_error(mods)
        asserts.true(
            env,
            error != None,
            "Expected a conflict for verbs: {}.".format(
                [m["verb"] for m in mods],
            ),
        )
        asserts.true(
            env,
            error.find(_impl_target) > -1,
            "Expected the conflict to name the target.",
        )
        asserts.true(
            env,
            error.find("copts") > -1,
            "Expected the conflict to name the attribute.",
        )

    return unittest.end(env)

validation_error_test = unittest.make(_validation_error_test)

def _unknown_targets_error_test(ctx):
    env = unittest.begin(ctx)

    decls = [
        build_decls.new("swift_library", _impl_target),
        build_decls.new("alias", "Bar.rspm"),
        scg.new_fn_call("exports_files", ["pkg_info.json"]),
    ]

    asserts.equals(
        env,
        None,
        bazel_target_mods.unknown_targets_error(
            decls,
            [bazel_target_mods.new(
                _verbs.add,
                _impl_target,
                "copts",
                values = ["-DFOO"],
            )],
        ),
    )

    error = bazel_target_mods.unknown_targets_error(
        decls,
        [
            bazel_target_mods.new(
                _verbs.add,
                "Nope.rspm.__impl",
                "copts",
                values = ["-DFOO"],
            ),
            bazel_target_mods.new(
                _verbs.set,
                "exports_files",
                "copts",
                value = "-DFOO",
            ),
        ],
    )
    asserts.true(env, error != None, "Expected an error.")
    asserts.true(
        env,
        error.find("Nope.rspm.__impl") > -1,
        "Expected the error to name the unknown target.",
    )
    asserts.true(
        env,
        error.find("Bar.rspm, Bar.rspm.__impl") > -1,
        "Expected the error to list the available declaration names.",
    )
    asserts.true(
        env,
        error.find("exports_files") > -1,
        """\
Expected the error to name the function call, which is not a modifiable \
declaration.\
""",
    )

    return unittest.end(env)

unknown_targets_error_test = unittest.make(_unknown_targets_error_test)

# MARK: - Apply

def _apply_test(ctx):
    env = unittest.begin(ctx)

    other_decl = build_decls.new(
        "swift_library",
        "Other.rspm.__impl",
        attrs = {"copts": ["-DOTHER"]},
    )
    decls = [_decl({"copts": ["-DGENERATED"]}), other_decl]

    # No modifications leaves the declarations untouched.
    asserts.equals(env, decls, bazel_target_mods.apply(decls, []))

    actual = bazel_target_mods.apply(
        decls,
        [bazel_target_mods.new(
            _verbs.add,
            _impl_target,
            "copts",
            values = ["-DFOO"],
        )],
    )
    asserts.equals(env, 2, len(actual))
    asserts.equals(env, ["-DGENERATED", "-DFOO"], actual[0].attrs["copts"])
    asserts.equals(env, "swift_library", actual[0].kind)
    asserts.equals(env, _impl_target, actual[0].name)

    # Unmodified declarations are passed through unchanged.
    asserts.equals(env, other_decl, actual[1])

    # The original declaration's attributes are not mutated.
    asserts.equals(env, ["-DGENERATED"], decls[0].attrs["copts"])

    return unittest.end(env)

apply_test = unittest.make(_apply_test)

def _apply_preserves_comments_test(ctx):
    env = unittest.begin(ctx)

    comments = ["# This target is generated.", "# Do not edit."]
    decl = build_decls.new(
        kind = "swift_library",
        name = _impl_target,
        attrs = {"copts": ["-DGENERATED"]},
        comments = comments,
    )

    actual = bazel_target_mods.apply(
        [decl],
        [bazel_target_mods.new(
            _verbs.add,
            _impl_target,
            "copts",
            values = ["-DFOO"],
        )],
    )
    asserts.equals(env, 1, len(actual))
    asserts.equals(env, comments, actual[0].comments)
    asserts.equals(env, ["-DGENERATED", "-DFOO"], actual[0].attrs["copts"])

    # The comments are rendered before the modified declaration.
    asserts.equals(
        env,
        """\
# This target is generated.
# Do not edit.
swift_library(
    name = "Bar.rspm.__impl",
    copts = [
        "-DGENERATED",
        "-DFOO",
    ],
)\
""",
        scg.to_starlark(actual[0]),
    )

    return unittest.end(env)

apply_preserves_comments_test = unittest.make(_apply_preserves_comments_test)

# MARK: - mods_by_repo

def _mods_by_repo_test(ctx):
    env = unittest.begin(ctx)

    tag_groups = [
        struct(
            verb = _verbs.set,
            tags = [struct(
                target = _impl_label,
                attr = "alwayslink",
                value = "False",
            )],
        ),
        struct(
            verb = _verbs.add,
            tags = [
                struct(
                    target = _impl_label,
                    attr = "copts",
                    values = ["-DFOO"],
                ),
                struct(
                    target = "@swiftpkg_baz//:Qux.rspm.__impl",
                    attr = "copts",
                    values = ["-DBAZ"],
                ),
            ],
        ),
        struct(
            verb = _verbs.add_select,
            tags = [struct(
                target = _impl_label,
                attr = "copts",
                values = {"//:release_build": ["-O2"]},
            )],
        ),
    ]

    actual = bazel_target_mods.mods_by_repo(tag_groups)
    asserts.equals(
        env,
        ["swiftpkg_baz", "swiftpkg_foo"],
        sorted(actual.keys()),
    )
    asserts.equals(
        env,
        [
            {
                "attr": "alwayslink",
                "target": _impl_target,
                "value": "False",
                "verb": _verbs.set,
            },
            {
                "attr": "copts",
                "target": _impl_target,
                "values": ["-DFOO"],
                "verb": _verbs.add,
            },
            {
                "attr": "copts",
                "target": _impl_target,
                "values": {"@@//:release_build": ["-O2"]},
                "verb": _verbs.add_select,
            },
        ],
        actual["swiftpkg_foo"],
    )
    asserts.equals(
        env,
        [{
            "attr": "copts",
            "target": "Qux.rspm.__impl",
            "values": ["-DBAZ"],
            "verb": _verbs.add,
        }],
        actual["swiftpkg_baz"],
    )

    asserts.equals(env, {}, bazel_target_mods.mods_by_repo([]))

    return unittest.end(env)

mods_by_repo_test = unittest.make(_mods_by_repo_test)

def _default_condition_test(ctx):
    env = unittest.begin(ctx)

    # The generated BUILD files live in external repositories and rely on the
    # `//conditions:default` pseudo-label, so it must never be canonicalized.
    asserts.equals(env, "//conditions:default", bzl_selects.default_condition)

    return unittest.end(env)

default_condition_test = unittest.make(_default_condition_test)

def bazel_target_mods_test_suite():
    return unittest.suite(
        "bazel_target_mods_tests",
        add_select_test,
        add_test,
        apply_preserves_comments_test,
        apply_test,
        canonicalize_condition_test,
        default_condition_test,
        encode_decode_test,
        mods_by_repo_test,
        new_error_test,
        ordering_test,
        parse_target_test,
        parse_value_test,
        set_select_test,
        set_test,
        unknown_targets_error_test,
        validation_error_test,
    )
