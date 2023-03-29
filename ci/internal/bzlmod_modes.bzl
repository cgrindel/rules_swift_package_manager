"""Module for converting bzlmod mode values."""

def _to_bool(bzlmod_mode):
    if bzlmod_mode == "enabled":
        return True
    elif bzlmod_mode == "disabled":
        return False
    fail("Unrecognized bzlmod_mode: {}".format(bzlmod_mode))

def _from_bool(enable_bzlmod):
    if enable_bzlmod:
        return "enabled"
    else:
        return "disabled"

bzlmod_modes = struct(
    to_bool = _to_bool,
    from_bool = _from_bool,
)
