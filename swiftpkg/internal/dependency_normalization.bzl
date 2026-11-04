"""Deduplicate generated dependency expressions without flattening select semantics."""

load(":build_decls.bzl", "build_decls")
load(":build_files.bzl", "build_files")
load(":load_statements.bzl", "load_statements")
load(":starlark_codegen.bzl", scg = "starlark_codegen")

def _parts(value):
    pending = [value]
    for _ in range(100):
        expanded = []
        changed = False
        for part in pending:
            if hasattr(part, "members"):
                expanded.extend(part.members)
                changed = True
            else:
                expanded.append(part)
        pending = expanded
        if not changed:
            break
    result = []
    for part in pending:
        if type(part) == "list" and all([type(v) == "string" for v in part]):
            result.append(list({v: True for v in part}))
        elif getattr(part, "operator", None) == "+":
            continue
        elif getattr(part, "fn_name", None) == "select" and len(part.args) == 1 and type(part.args[0]) == "dict":
            branches = part.args[0]
            if not all([type(v) == "list" and all([type(d) == "string" for d in v]) for v in branches.values()]):
                return None
            result.append({k: list({d: True for d in v}) for k, v in branches.items()})
        else:
            # An arbitrary user expression is outside the generated list/select IR.
            return None
    return result

def _join(parts):
    if not parts:
        return []
    members = []
    for part in parts:
        if members:
            members.append(scg.new_op("+"))
        members.append(scg.new_fn_call("select", part) if type(part) == "dict" else part)
    return scg.new_expr(*members)

def _normalize(value, prefix):
    parts = _parts(value)
    if parts == None:
        return struct(value = value, helpers = [])
    occurrences = {}
    unconditional = {}
    for part in parts:
        values = part if type(part) == "list" else [d for branch in part.values() for d in branch]
        for dep in {v: True for v in values}:
            occurrences[dep] = occurrences.get(dep, 0) + 1
            if type(part) == "list":
                unconditional[dep] = True
    repeated = {dep: True for dep, count in occurrences.items() if count > 1}
    if not repeated:
        return struct(value = _join(parts), helpers = [])
    cleaned = []
    for part in parts:
        if type(part) == "list":
            kept = [d for d in part if d not in repeated]
            if kept:
                cleaned.append(kept)
        else:
            branches = {k: [d for d in v if d not in repeated] for k, v in part.items()}
            if any(branches.values()) or "//conditions:default" not in branches:
                cleaned.append(branches)
    helpers = []
    for index, dep in enumerate(sorted(repeated)):
        if dep in unconditional:
            cleaned.append([dep])
            continue
        if not helpers:
            helpers.extend([
                build_decls.new("config_setting", prefix + "on", {"values": {"stamp": "1"}}),
                build_decls.new("config_setting", prefix + "off", {"values": {"stamp": "0"}}),
                build_decls.new("selects.config_setting_group", prefix + "true", {"match_any": [":" + prefix + "on", ":" + prefix + "off"]}),
                build_decls.new("selects.config_setting_group", prefix + "false", {"match_all": [":" + prefix + "on", ":" + prefix + "off"]}),
            ])
        predicates = []
        for part_index, part in enumerate(parts):
            if type(part) != "dict" or not any([dep in v for v in part.values()]):
                continue
            name = "{}{}_{}".format(prefix, index, part_index)

            # Keep ALL branches, including exclusions and default. This preserves
            # specialization and nonempty defaults, rather than guessing overlap.
            helpers.append(build_decls.new("alias", name, {
                "actual": scg.new_fn_call("select", {
                    k: ":" + prefix + ("true" if dep in v else "false")
                    for k, v in part.items()
                }),
            }))
            predicates.append(":" + name)
        name = "{}{}_present".format(prefix, index)
        helpers.append(build_decls.new("selects.config_setting_group", name, {"match_any": predicates}))
        cleaned.append({":" + name: [dep], "//conditions:default": []})
    return struct(value = _join(cleaned), helpers = helpers)

def _build_file(build_file):
    decls = []
    helpers = []
    names = {d.name: True for d in build_file.decls}
    for index, decl in enumerate(build_file.decls):
        if "deps" not in getattr(decl, "attrs", {}):
            decls.append(decl)
            continue
        prefix = "_rspm_unique_deps_{}_".format(index)
        for _ in range(len(names) + 1):
            if not any([name and name.startswith(prefix) for name in names]):
                break
            prefix += "_"
        result = _normalize(decl.attrs["deps"], prefix)
        attrs = dict(decl.attrs)
        attrs["deps"] = result.value
        decls.append(build_decls.new(decl.kind, decl.name, attrs, decl.comments))
        helpers.extend(result.helpers)
    return build_files.merge(build_files.new(
        load_stmts = build_file.load_stmts + ([load_statements.new("@bazel_skylib//lib:selects.bzl", "selects")] if helpers else []),
        package_attrs = build_file.package_attrs,
        decls = decls + helpers,
    ))

dependency_normalization = struct(build_file = _build_file, normalize = _normalize)
