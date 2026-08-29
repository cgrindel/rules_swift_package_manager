"""Module for buildozer-style modifications to generated Bazel declarations.

The `swift_deps` module extension lets the root module adjust attributes on the
declarations that this ruleset generates for a Swift package. The tags are
modeled on `buildozer` commands (`set`, `add`) plus `select()`-aware variants.

There is deliberately no allowlist of attribute names. An attribute name that
the generated rule does not understand fails later, when Bazel loads the
generated `BUILD.bazel` file, with Bazel's own error message. This is a
use-at-your-own-risk feature.
"""

load(":build_decls.bzl", "build_decls")
load(":bzl_selects.bzl", "bzl_selects")
load(":starlark_codegen.bzl", scg = "starlark_codegen")

# MARK: - Verbs

_SET = "set"
_ADD = "add"
_SET_SELECT = "set_select"
_ADD_SELECT = "add_select"

_ALL_VERBS = [_SET, _ADD, _SET_SELECT, _ADD_SELECT]

# The verbs that replace an attribute value. At most one of these may be
# declared for any (target, attr) pair.
_SETTER_VERBS = [_SET, _SET_SELECT]

# Modifications for a (target, attr) pair are applied one group at a time. The
# declaration order is preserved inside a group.
_VERB_GROUPS = [_SETTER_VERBS, [_ADD], [_ADD_SELECT]]

_verbs = struct(
    add = _ADD,
    add_select = _ADD_SELECT,
    all = _ALL_VERBS,
    set = _SET,
    set_select = _SET_SELECT,
)

# MARK: - Value Parsing

def _parse_value(value):
    """Parse an attribute value `string` the way `buildozer` does.

    Args:
        value: The value as a `string`.

    Returns:
        A `bool` for `true`/`false` (case-insensitive), an `int` for an
        all-digit value with an optional leading `-`, otherwise the original
        `string`.
    """
    lowered = value.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    digits = value[1:] if value.startswith("-") else value
    if digits != "" and digits.isdigit():
        return int(value)
    return value

# MARK: - Condition Canonicalization

# The canonical spelling of the `select()` default branch. Bazel accepts it, but
# the rest of the generated output uses the pseudo-label spelling, and only the
# pseudo-label spelling is recognized as the default branch by this module.
_CANONICAL_DEFAULT_CONDITION = "@@" + bzl_selects.default_condition

def _condition_error(condition):
    """Check that a `select()` key declared by the root module is usable.

    Args:
        condition: The `select()` key as a `string`.

    Returns:
        A `string` describing the problem, or `None` if there is none.
    """
    if condition == bzl_selects.default_condition:
        return None
    if condition == _CANONICAL_DEFAULT_CONDITION:
        return None
    if condition.startswith("@@"):
        return None
    if condition.startswith("@"):
        return """\
Invalid `select()` condition '{condition}'. An apparent repository name (a \
single `@`) is resolved using the repository mapping of the repository that \
contains the label. The condition is written into a generated repository, so it \
would resolve against `rules_swift_package_manager`'s repository mapping \
instead of your root module's. Use a label that is relative to the main \
repository (e.g. `//:release_build`), which is canonicalized for you, or a \
canonical label (e.g. `@@some_repo+//:setting`).\
""".format(condition = condition)
    if condition.startswith("//"):
        return None
    return """\
Invalid `select()` condition '{condition}'. Conditions must be absolute labels \
(e.g. `//:release_build` or `@@some_repo+//:setting`).\
""".format(condition = condition)

def _canonicalize_condition(condition):
    """Canonicalize a `select()` key declared by the root module.

    The generated declarations live in an external repository, so a key that is
    relative to the main repository (e.g. `//:release_build`) must be written in
    its canonical form (e.g. `@@//:release_build`) to keep pointing at the root
    module. Only the root module may declare these tags, so the canonical form
    is always the main repository.

    A key that names an apparent repository (a single `@`) is rejected. It would
    be resolved against the repository mapping of the generated repository, not
    the root module's, which silently points at a different repository.

    Args:
        condition: The `select()` key as a `string`.

    Returns:
        The canonicalized `select()` key as a `string`.
    """
    error = _condition_error(condition)
    if error != None:
        fail(error)
    if condition == _CANONICAL_DEFAULT_CONDITION:
        return bzl_selects.default_condition
    if condition == bzl_selects.default_condition or condition.startswith("@@"):
        return condition
    return "@@" + condition

# MARK: - Target Label Parsing

def _parse_target(target):
    """Parse the `target` label `string` of a modification tag.

    Every declaration that this ruleset generates for a Swift package lands in
    the root package of the generated repository. Only labels of the form
    `@repo_name//:target_name` are supported.

    Args:
        target: A label `string` (e.g. `@swiftpkg_foo//:Bar.rspm.__impl`).

    Returns:
        A `struct` with a `repo_name`, a `name` and an `error`. The `error` is
        `None` when the label was parsed successfully; otherwise, it is a
        `string` describing the problem and the other fields are `None`.
    """

    def _error(reason):
        return struct(
            repo_name = None,
            name = None,
            error = """\
Invalid `swift_deps` target modification label '{target}'. {reason} Labels must \
be of the form `@repo_name//:target_name` (e.g. \
`@swiftpkg_foo//:Bar.rspm.__impl`).\
""".format(reason = reason, target = target),
        )

    if not target.startswith("@"):
        return _error("The label must start with a repository name.")
    remainder = target[1:]

    # Accept the canonical `@@repo//:name` spelling, as well.
    if remainder.startswith("@"):
        remainder = remainder[1:]
    pkg_idx = remainder.find("//")
    if pkg_idx < 0:
        return _error("The label must contain a package separator (`//`).")
    repo_name = remainder[:pkg_idx]
    if repo_name == "":
        return _error("The repository name must not be empty.")
    rest = remainder[pkg_idx + len("//"):]
    name_idx = rest.find(":")
    if name_idx < 0:
        return _error("The label must contain a target separator (`:`).")
    package = rest[:name_idx]
    name = rest[name_idx + 1:]
    if package != "":
        return _error("""\
All generated declarations are in the root package of the generated \
repository, but this label names the package '{package}'.\
""".format(package = package))
    if name == "":
        return _error("The target name must not be empty.")
    return struct(repo_name = repo_name, name = name, error = None)

# MARK: - Modifications

def _new_error(verb, target, attr, value = None, values = None):
    """Check the inputs for `bazel_target_mods.new`.

    Args:
        verb: One of `bazel_target_mods.verbs`.
        target: The name of the generated declaration as a `string`.
        attr: The name of the attribute as a `string`.
        value: Optional. The `string` value for the `set` verb.
        values: Optional. A `list` of `string` values for the `add` verb, or a
            `dict` mapping `select()` conditions to a `list` of `string` values
            for the `set_select` and `add_select` verbs.

    Returns:
        A `string` describing the problem, or `None` if there is none.
    """
    if verb not in _ALL_VERBS:
        return "Unrecognized target modification verb '{verb}'. Expected one of: {expected}.".format(
            expected = ", ".join(_ALL_VERBS),
            verb = verb,
        )
    if not target:
        return "A target modification must specify a target name."
    if not attr:
        return "A target modification for '{}' must specify an attribute name.".format(target)
    if attr == "name":
        return """\
The target modification for '{target}' must not modify the `name` attribute. \
The name of a generated declaration is written separately from its other \
attributes, so modifying it would emit a duplicate `name` keyword and the \
generated `BUILD.bazel` file would not load.\
""".format(target = target)

    if verb == _SET:
        if type(value) != "string":
            return """\
The `set` modification for '{target}' attribute '{attr}' must specify a \
`string` value.\
""".format(attr = attr, target = target)
        return None

    if verb == _ADD:
        if not values:
            return """\
The `add` modification for '{target}' attribute '{attr}' must specify at least \
one value.\
""".format(attr = attr, target = target)
        return None

    if not values:
        return """\
The `{verb}` modification for '{target}' attribute '{attr}' must specify at \
least one `select()` condition.\
""".format(attr = attr, target = target, verb = verb)
    return None

def _new(verb, target, attr, value = None, values = None):
    """Create a modification for a generated declaration.

    Args:
        verb: One of `bazel_target_mods.verbs`.
        target: The name of the generated declaration as a `string`.
        attr: The name of the attribute as a `string`.
        value: Optional. The `string` value for the `set` verb. It is written
            into the generated `BUILD.bazel` file verbatim. Label values are not
            remapped, so a value such as `//:my_lib` resolves inside the
            generated repository. Use `@@//:my_lib` to name a target in the main
            repository.
        values: Optional. A `list` of `string` values for the `add` verb, or a
            `dict` mapping `select()` conditions to a `list` of `string` values
            for the `set_select` and `add_select` verbs. The values are written
            into the generated `BUILD.bazel` file verbatim. Label values are not
            remapped, so a value such as `//:my_lib` resolves inside the
            generated repository. Use `@@//:my_lib` to name a target in the main
            repository.

    Returns:
        A `dict` representing the modification.
    """
    error = _new_error(verb, target, attr, value = value, values = values)
    if error != None:
        fail(error)

    if verb == _SET:
        return {"attr": attr, "target": target, "value": value, "verb": verb}

    if verb == _ADD:
        return {
            "attr": attr,
            "target": target,
            "values": list(values),
            "verb": verb,
        }

    canonical_values = {}
    for (condition, condition_values) in values.items():
        canonical_values[_canonicalize_condition(condition)] = list(
            condition_values,
        )
    return {
        "attr": attr,
        "target": target,
        "values": canonical_values,
        "verb": verb,
    }

def _mods_by_repo(tag_groups):
    """Convert modification tags into modifications grouped by repository name.

    Args:
        tag_groups: A `list` of `struct` values with a `verb` `string` and a
            `tags` `list`. Each tag must have a `target` and an `attr`, plus a
            `value` for the `set` verb or `values` for the other verbs.

    Returns:
        A `dict` mapping a generated repository name to a `list` of
        modification `dict` values.
    """
    mods_by_repo = {}
    for tag_group in tag_groups:
        verb = tag_group.verb
        for tag in tag_group.tags:
            parsed = _parse_target(tag.target)
            if parsed.error != None:
                fail(parsed.error)
            if verb == _SET:
                mod = _new(verb, parsed.name, tag.attr, value = tag.value)
            else:
                mod = _new(verb, parsed.name, tag.attr, values = tag.values)
            mods_by_repo.setdefault(parsed.repo_name, []).append(mod)

    for (repo_name, mods) in mods_by_repo.items():
        error = _validation_error(mods)
        if error != None:
            fail("""\
Invalid `swift_deps` target modifications for repository '@{repo_name}'. \
{error}\
""".format(error = error, repo_name = repo_name))

    return mods_by_repo

# MARK: - Encode/Decode

def _encode(mods):
    """Encode modifications so that they can be passed to a repository rule.

    Args:
        mods: A `list` of modification `dict` values.

    Returns:
        A JSON `string`. An empty `string` is returned when there are no
        modifications.
    """
    if not mods:
        return ""
    return json.encode(mods)

def _decode(mods_json):
    """Decode modifications from a repository rule attribute value.

    Args:
        mods_json: A JSON `string` as returned by `bazel_target_mods.encode`.

    Returns:
        A `list` of modification `dict` values.
    """
    if not mods_json:
        return []
    return json.decode(mods_json)

# MARK: - Validation

def _validation_error(mods):
    """Check modifications for conflicts.

    Args:
        mods: A `list` of modification `dict` values.

    Returns:
        A `string` describing the conflict, or `None` if there is none.
    """
    setter_counts = {}
    for mod in mods:
        if mod["verb"] not in _SETTER_VERBS:
            continue
        key = (mod["target"], mod["attr"])
        setter_counts[key] = setter_counts.get(key, 0) + 1
    conflicts = sorted([k for k in setter_counts if setter_counts[k] > 1])
    if not conflicts:
        return None
    return """\
At most one `bazel_target_set` or `bazel_target_set_select` tag may be declared \
for a target attribute. Conflicts: {conflicts}.\
""".format(
        conflicts = "; ".join([
            "'{}' attribute '{}'".format(target, attr)
            for (target, attr) in conflicts
        ]),
    )

def _validate(mods):
    """Fail if the modifications conflict with each other.

    Args:
        mods: A `list` of modification `dict` values.
    """
    error = _validation_error(mods)
    if error != None:
        fail(error)

def _unknown_targets_error(decls, mods):
    """Check that every modification names an existing declaration.

    Args:
        decls: A `list` of declaration `struct` values as returned by
            `build_decls.new`.
        mods: A `list` of modification `dict` values.

    Returns:
        A `string` describing the unknown targets, or `None` if there are none.
    """
    available = _modifiable_decl_names(decls)
    unknown = sorted({
        mod["target"]: None
        for mod in mods
        if mod["target"] not in available
    }.keys())
    if not unknown:
        return None
    return """\
Target modifications were declared for unknown generated targets: {unknown}. \
Available generated targets are: {available}.\
""".format(
        available = ", ".join(sorted(available)),
        unknown = ", ".join(unknown),
    )

def _modifiable_decl_names(decls):
    return [
        decl.name
        for decl in decls
        if decl.name and hasattr(decl, "attrs")
    ]

# MARK: - Application

def _apply(decls, mods):
    """Apply modifications to generated declarations.

    Args:
        decls: A `list` of declaration `struct` values as returned by
            `build_decls.new`.
        mods: A `list` of modification `dict` values.

    Returns:
        A `list` of declaration `struct` values with the modifications applied.
    """
    if not mods:
        return decls
    _validate(mods)
    error = _unknown_targets_error(decls, mods)
    if error != None:
        fail(error)

    mods_by_target = {}
    for mod in mods:
        mods_by_target.setdefault(mod["target"], []).append(mod)

    new_decls = []
    for decl in decls:
        target_mods = mods_by_target.get(decl.name) if decl.name else None
        if not target_mods:
            new_decls.append(decl)
            continue
        attrs = dict(decl.attrs)
        for mod in _ordered_mods(target_mods):
            _apply_mod(attrs, mod)
        new_decls.append(build_decls.new(
            kind = decl.kind,
            name = decl.name,
            attrs = attrs,
            comments = decl.comments,
        ))
    return new_decls

def _ordered_mods(mods):
    """Order modifications by verb, preserving declaration order per verb.

    Args:
        mods: A `list` of modification `dict` values.

    Returns:
        A `list` of modification `dict` values in application order.
    """
    ordered = []
    for verbs in _VERB_GROUPS:
        ordered.extend([mod for mod in mods if mod["verb"] in verbs])
    return ordered

def _apply_mod(attrs, mod):
    verb = mod["verb"]
    attr_name = mod["attr"]
    if verb == _SET:
        attrs[attr_name] = _parse_value(mod["value"])
    elif verb == _SET_SELECT:
        attrs[attr_name] = _new_select(mod["values"], add_default = False)
    elif verb == _ADD:
        _append(attrs, attr_name, list(mod["values"]))
    elif verb == _ADD_SELECT:
        _append(
            attrs,
            attr_name,
            _new_select(mod["values"], add_default = True),
        )
    else:
        fail("Unrecognized target modification verb '{}'.".format(verb))

def _new_select(values, add_default):
    """Create a `select()` function call for the specified conditions.

    Args:
        values: A `dict` mapping `select()` conditions to a `list` of values.
        add_default: A `bool` specifying whether a `//conditions:default` branch
            should be added when the caller did not provide one.

    Returns:
        A `struct` as returned by `starlark_codegen.new_fn_call`.
    """
    select_dict = {}
    for condition in sorted(values.keys()):
        if condition == bzl_selects.default_condition:
            continue
        select_dict[condition] = list(values[condition])

    # Keep the default branch last, matching the rest of the generated output.
    if bzl_selects.default_condition in values:
        select_dict[bzl_selects.default_condition] = list(
            values[bzl_selects.default_condition],
        )
    elif add_default:
        select_dict[bzl_selects.default_condition] = []
    return scg.new_fn_call("select", select_dict)

def _append(attrs, attr_name, new_part):
    """Append a value to an attribute, creating the attribute if necessary.

    Args:
        attrs: A `dict` of declaration attributes. It is modified in place.
        attr_name: The name of the attribute as a `string`.
        new_part: The value to append.
    """
    existing = attrs.get(attr_name)
    if existing == None:
        attrs[attr_name] = new_part
        return

    # Concatenate plain lists directly. Everything else (a Starlark codegen
    # expression such as `[...] + select({...})`, or a scalar) is composed into
    # an expression so that the new value is always last.
    if type(existing) == "list" and type(new_part) == "list":
        attrs[attr_name] = existing + new_part
        return
    attrs[attr_name] = scg.new_expr(existing, scg.new_op("+"), new_part)

bazel_target_mods = struct(
    apply = _apply,
    canonicalize_condition = _canonicalize_condition,
    condition_error = _condition_error,
    decode = _decode,
    encode = _encode,
    mods_by_repo = _mods_by_repo,
    new = _new,
    new_error = _new_error,
    ordered_mods = _ordered_mods,
    parse_target = _parse_target,
    parse_value = _parse_value,
    unknown_targets_error = _unknown_targets_error,
    validate = _validate,
    validation_error = _validation_error,
    verbs = _verbs,
)
