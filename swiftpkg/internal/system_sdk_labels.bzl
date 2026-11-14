"""SDK label identities in RSPM's mapping, without resolving package-local labels."""

_APPARENT_PREFIX = "@system_sdk//:"
_CANONICAL_PREFIX = "@@{}//:".format(Label("@system_sdk//:BUILD.bazel").repo_name)

def _key(value):
    if value.startswith(_APPARENT_PREFIX):
        return _CANONICAL_PREFIX + value[len(_APPARENT_PREFIX):]
    return value

def _is_sdk(value):
    return _key(value).startswith(_CANONICAL_PREFIX)

system_sdk_labels = struct(key = _key, is_sdk = _is_sdk)
