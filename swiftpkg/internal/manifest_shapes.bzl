"""Cheap shape checks for cached `dump.json` and `desc.json` manifests.

`pkginfos.new_from_manifests` indexes the manifests directly and fails on a
missing key. A cached manifest that is valid JSON but has the wrong shape (for
example, a hand-edited file) must mark the slice stale instead, so the
extension runs `check` first.
"""

def _type_error(what, key, want, value):
    if value == None:
        return "{}: missing `{}`".format(what, key)
    return "{}: `{}` is a {}, expected a {}".format(what, key, type(value), want)

def _check_keys(what, manifest, specs):
    for key, want in specs:
        value = manifest.get(key)
        if type(value) != want:
            return _type_error(what, key, want, value)
    return None

# The keys that `pkginfos` indexes directly on each list item.
_DUMP_PLATFORM_KEYS = [("platformName", "string"), ("version", "string")]
_DUMP_PRODUCT_KEYS = [("name", "string"), ("type", "dict"), ("targets", "list")]
_DUMP_TARGET_KEYS = [
    ("name", "string"),
    ("type", "string"),
    ("dependencies", "list"),
    ("settings", "list"),
]
_DESC_TARGET_NAME_KEYS = [("name", "string")]

# Required only on desc targets named in dump; the parser reads only `name`
# from the others.
_DESC_TARGET_KEYS = [
    ("path", "string"),
    ("c99name", "string"),
    ("module_type", "string"),
    ("sources", "list"),
]

# The extra key each desc dependency type needs.
_DESC_DEPENDENCY_KEYS = {
    "fileSystem": [("path", "string")],
    "registry": [],
    "sourceControl": [("url", "string")],
}

def _check_item(what, item, specs):
    if type(item) != "dict":
        return "{}: not an object".format(what)
    if type(item.get("name")) == "string":
        what = "{} `{}`".format(what, item["name"])
    return _check_keys(what, item, specs)

def _dump_dependency_identity(dep):
    """The identity of a dump dependency, or `None` if it has none."""
    if type(dep) != "dict":
        return None
    for kind in ["sourceControl", "fileSystem", "registry"]:
        providers = dep.get(kind)
        if type(providers) == "list" and providers:
            provider = providers[0]
            if type(provider) == "dict" and type(provider.get("identity")) == "string":
                return provider["identity"]
    return None

def _check_desc_dependency(dep):
    if type(dep) != "dict":
        return "desc dependency: not an object"
    identity = dep.get("identity")
    if type(identity) != "string":
        return _type_error("desc dependency", "identity", "string", identity)
    what = "desc dependency `{}`".format(identity)
    dep_type = dep.get("type")
    if dep_type not in _DESC_DEPENDENCY_KEYS:
        return "{}: unknown `type` {}".format(what, json.encode(dep_type))
    return _check_keys(what, dep, _DESC_DEPENDENCY_KEYS[dep_type])

def _check(dump, desc):
    """Checks that a dump/desc manifest pair has the shape the parser needs.

    Args:
        dump: The decoded `dump.json` `dict`.
        desc: The decoded `desc.json` `dict`.

    Returns:
        `None` when the pair is usable; otherwise, an error `string`.
    """
    err = _check_keys("dump", dump, [
        ("name", "string"),
        ("toolsVersion", "dict"),
        ("platforms", "list"),
        ("dependencies", "list"),
        ("products", "list"),
        ("targets", "list"),
    ])
    if err != None:
        return err
    if type(dump["toolsVersion"].get("_version")) != "string":
        return "dump: missing `toolsVersion._version`"

    # Indexed directly, but `null` is allowed.
    if "swiftLanguageVersions" not in dump:
        return "dump: missing `swiftLanguageVersions`"
    for platform in dump["platforms"]:
        err = _check_item("dump platform", platform, _DUMP_PLATFORM_KEYS)
        if err != None:
            return err

    err = _check_keys("desc", desc, [
        ("name", "string"),
        ("path", "string"),
        ("targets", "list"),
        ("dependencies", "list"),
    ])
    if err != None:
        return err

    for product in dump["products"]:
        err = _check_item("dump product", product, _DUMP_PRODUCT_KEYS)
        if err != None:
            return err

    dump_target_names = {}
    for target in dump["targets"]:
        err = _check_item("dump target", target, _DUMP_TARGET_KEYS)
        if err != None:
            return err
        dump_target_names[target["name"]] = None

    desc_targets_by_name = {}
    for target in desc["targets"]:
        err = _check_item("desc target", target, _DESC_TARGET_NAME_KEYS)
        if err != None:
            return err
        desc_targets_by_name[target["name"]] = target

    # The parser looks up every dump target in the desc targets.
    for name in dump_target_names:
        target = desc_targets_by_name.get(name)
        if target == None:
            return "target `{}` is in dump but not in desc".format(name)
        err = _check_item("desc target", target, _DESC_TARGET_KEYS)
        if err != None:
            return err

    dump_ids = {}
    for dep in dump["dependencies"]:
        identity = _dump_dependency_identity(dep)
        if identity == None:
            return (
                "dump dependency: no `sourceControl`, `fileSystem`, or " +
                "`registry` entry with an `identity`"
            )
        dump_ids[identity] = None
    for dep in desc["dependencies"]:
        err = _check_desc_dependency(dep)
        if err != None:
            return err
        if dep["identity"] not in dump_ids:
            return "dependency `{}` is in desc but not in dump".format(
                dep["identity"],
            )
    return None

manifest_shapes = struct(
    check = _check,
)
