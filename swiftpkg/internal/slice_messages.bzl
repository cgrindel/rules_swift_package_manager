"""Message text shared by the stale-slice rules and generated `select()`s."""

def _stale(slice_dir, config):
    """Returns the message for a stale slice.

    Args:
        slice_dir: The slice directory as a `string`.
        config: The config label of the slice as a `string`.

    Returns:
        The message as a `string`.
    """
    return (
        "slice `{slice_dir}` (config `{config}`) is stale; " +
        "run `bazel run @swift_package//:cache` under flags that select " +
        "that config"
    ).format(slice_dir = slice_dir, config = config)

def _no_match(configs):
    """Returns the message for a `select()` that matches no slice.

    Args:
        configs: A `list` of config labels that were tried.

    Returns:
        The message as a `string`.
    """
    return "No slice matches the current configuration; tried: {}".format(
        ", ".join(sorted(configs)),
    )

slice_messages = struct(
    stale = _stale,
    no_match = _no_match,
)
