"""Module for resolving registry URLs from scopes."""

def _read(repository_ctx):
    registry_config_json = repository_ctx.read(
        Label("@//:.swiftpm/configuration/registries.json"),
    )
    registry_config = _new_from_json(registry_config_json)
    return registry_config

def _new_from_json(json_str):
    """Creates a registry config from a JSON string.

    Args:
        json_str: A JSON `string` value.

    Returns:
        A `dict` that contains a registry config.
    """
    return json.decode(json_str)

def _get_url_for_scope(registry_config, scope):
    registries = registry_config.get("registries", {})

    registry = registries.get(scope) or registries.get("[default]")

    if not registry:
        fail("No registry configured for scope '%s'." % scope)

    return registry["url"]

registry_configs = struct(
    read = _read,
    get_url_for_scope = _get_url_for_scope,
)
