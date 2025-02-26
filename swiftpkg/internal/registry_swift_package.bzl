"""Implementation for `registry_swift_package`."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:structs.bzl", "structs")
load("//swiftpkg/internal:pkg_ctxs.bzl", "pkg_ctxs")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:repo_rules.bzl", "repo_rules")
load(
    "//swiftpkg/internal:swift_package_tool_attrs.bzl",
    "swift_package_tool_attrs",
)

# The key for the default registry in the registries JSON.
_DEFAULT_REGISTRY_KEY = "[default]"

# The name of the source archive resource in the package JSON.
_SOURCE_ARCHIVE_NAME = "source-archive"

# The headers to use when making requests to the registry.
_REGISTRY_JSON_ACCEPT_HEADER = {
    "Accept": "application/vnd.swift.registry.v1+json",
}
_REGISTRY_ZIP_ACCEPT_HEADER = {
    "Accept": "application/vnd.swift.registry.v1+zip",
}

def _get_id(id):
    """Returns the scope and name from the package identifier.

    https://github.com/swiftlang/swift-evolution/blob/main/proposals/0292-package-registry-service.md#package-identity
    """
    scope, name = id.split(".")
    return struct(
        scope = scope,
        name = name,
    )

def _get_registries(registries_json):
    """Returns the registry structs from the registries JSON."""
    default_registry = None
    scoped_registries = {}

    for registry_key, registry in registries_json.items():
        if registry_key == _DEFAULT_REGISTRY_KEY:
            default_registry = registry
        else:
            scoped_registries[registry_key] = registry.get("url")

    if not default_registry and not scoped_registries:
        fail("No registries were parsed from the `registries` field: {registries}".format(registries = registries_json))

    return struct(
        default = default_registry.get("url"),
        scoped = scoped_registries,
    )

def _get_registry_url(*, id, registries):
    """Returns the registry URL for the given package identifier.

    Prefers a scoped registry if it is defined.
    """
    return registries.scoped.get(id.scope, registries.default)

def _download_and_parse_package_json(*, id, output, repository_ctx, registry_url, version):
    """Downloads and parses the package JSON metadata from the registry.

    https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/Registry.md#42-fetch-information-about-a-package-release
    """
    package_json_url = paths.join(
        registry_url,
        id.scope,
        id.name,
        version,
    )
    repository_ctx.download(
        headers = _REGISTRY_JSON_ACCEPT_HEADER,
        url = package_json_url,
        output = output,
    )

    return json.decode(repository_ctx.read(output))

def _download_archive(*, checksum, id, output, repository_ctx, registry_url, version):
    """Downloads the specific version of the archive from the registry.

    https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/Registry.md#44-download-source-archive
    """
    archive_url = paths.join(
        registry_url,
        id.scope,
        id.name,
        "{version}.zip".format(version = version),
    )

    # NOTE: because the Swift Package Registry spec does not define the
    # allowable prefixes within the archive, we cannot rely on Bazel's
    # `stripPrefix` feature to strip the parent directory reliably.
    # Instead, we'll download and extract to a temporary location and then
    # move the contents to the output.
    download_output = "{output}/download".format(output = output)

    # NOTE: this requires Bazel 7.1 or later to use `headers`
    # which must be set to reach this endpoint.
    repository_ctx.download_and_extract(
        headers = _REGISTRY_ZIP_ACCEPT_HEADER,
        url = archive_url,
        output = download_output,
        sha256 = checksum,
    )

    # Find the prefix of the downloaded archive.
    find_prefix_result = repository_ctx.execute(["ls", "-1", download_output])
    if find_prefix_result.return_code != 0:
        fail("""\
Failed to list contents of the downloaded archive from: {}\
""".format(archive_url))

    possible_prefixes = find_prefix_result.stdout.strip().split("\n")

    if not possible_prefixes:
        fail("""\
No contents were found in the downloaded archive from: {}\
""".format(archive_url))

    if len(possible_prefixes) > 1:
        fail("""\
Expected a single prefix for the source archive, found: {}\
""".format(possible_prefixes))

    archive_directory = "{}/{}".format(download_output, possible_prefixes[0])

    # Move the contents of the temporary location to the requested output,
    # we use a cp and rm instead of mv to ensure only the contents are moved
    # (and not the parent directory).
    cp_result = repository_ctx.execute(["cp", "-a", "{}/.".format(archive_directory), output])
    if cp_result.return_code != 0:
        fail("""\
Failed to copy the contents of the downloaded archive from: {}\
to: {}\
""".format(archive_directory, output))
    repository_ctx.execute(["rm", "-rf", download_output])

def _get_source_archive_checksum(*, package_json):
    """Returns the checksum for the source archive from the package JSON."""
    source_archive = None
    for resource in package_json.get("resources", []):
        if resource.get("name") == _SOURCE_ARCHIVE_NAME:
            source_archive = resource
            break

    if not source_archive:
        fail("""\
No source archive was found in the package JSON: {package_json}\
""".format(package_json = package_json))

    return source_archive.get("checksum")

def _get_resolved_pin_for_url(
        *,
        registry_url,
        repository_ctx,
        resolved_pkg_map,
        url):
    """Returns the resolved pin for the given URL.

    This registry endpoint is provided when determining a
    package's registry identity given only the URL of the package.

    https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/Registry.md#45-lookup-package-identifiers-registered-for-a-url
    """

    registry_identities_url = paths.join(
        registry_url,
        "identifiers",
    )
    curl_args = [
        "curl",
        "-s",
        "-H",
        "\"Accept: {accept_header}\"".format(
            accept_header = _REGISTRY_JSON_ACCEPT_HEADER["Accept"],
        ),
        "-G",
        "-d",
        "url={url}".format(url = url),
        "{url}".format(url = registry_identities_url),
    ]

    exec_result = repository_ctx.execute(curl_args)
    if exec_result.return_code != 0:
        fail("Failed to get registry identities for {url}: {output}".format(
            url = url,
            output = exec_result.stdout + exec_result.stderr,
        ))

    result_json = json.decode(exec_result.stdout)
    if not result_json:
        fail("Failed to decode registry identities for {url}: {output}".format(
            url = url,
            output = exec_result.stdout,
        ))

    identifiers = result_json.get("identifiers", [])

    # TODO: is this what SPM does? for now,
    # pick the first matching identity from the resolved package map.
    resolved_pin = None
    for pin in resolved_pkg_map.get("pins", []):
        if pin.get("identity") in identifiers:
            resolved_pin = pin
            break

    return resolved_pin

def _replace_scm_identities_in_pkg_info(
        *,
        pkg_info,
        registries,
        repository_ctx,
        resolved_pkg_map):
    """Replaces the SCM identity of the dependencies in provided package info \
    and resolved package map.
    """
    replaced_dependencies = []
    replaced_pkg_info = structs.to_dict(pkg_info)

    for dep in pkg_info.dependencies:
        # Only replace SCM dependencies.
        if not dep.source_control:
            replaced_dependencies.append(dep)
            continue
        if not dep.source_control.pin or not dep.source_control.pin.location:
            # buildifier: disable=print
            print("""\
Unable to find URL for {identity}, cannot replace SCM identity\
""".format(identity = dep.identity))
            replaced_dependencies.append(dep)
            continue

        # Find first identifier from any of the registries which matches
        # the resolved identity, preferring scoped registries first.
        registry_urls = registries.scoped.values() + [registries.default]
        resolved_pin = None
        for registry_url in registry_urls:
            resolved_pin = _get_resolved_pin_for_url(
                registry_url = registry_url,
                repository_ctx = repository_ctx,
                resolved_pkg_map = resolved_pkg_map,
                url = dep.source_control.pin.location,
            )
            if resolved_pin:
                break

        if not resolved_pin:
            # buildifier: disable=print
            print("""\
Unable to find resolved pin for {identity}, cannot replace SCM identity\
""".format(identity = dep.identity))
            replaced_dependencies.append(dep)
            continue

        replaced_dep = pkginfos.new_dependency(
            identity = resolved_pin.get("identity"),
            name = dep.name,
            registry = pkginfos.new_registry(
                pin = resolved_pin,
            ),
        )
        replaced_dependencies.append(replaced_dep)

    replaced_pkg_info["dependencies"] = replaced_dependencies
    return pkginfos.new(**replaced_pkg_info)

def _registry_swift_package_impl(repository_ctx):
    """Implementation for the `registry_swift_package` repository rule."""
    directory = str(repository_ctx.path("."))
    env = repo_rules.get_exec_env(repository_ctx)
    id = _get_id(repository_ctx.attr.id)
    version = repository_ctx.attr.version

    # TODO: potentially use the other fields here like `authentication`,
    # for now just use the `registries` field.
    registries_json = json.decode(
        repository_ctx.read(repository_ctx.attr.registries),
    ).get("registries")
    registries = _get_registries(registries_json)

    registry_url = _get_registry_url(
        id = id,
        registries = registries,
    )

    # Get the checksum for the source archive.
    repository_ctx.report_progress(
        "Downloading package metadata for {scope}.{name}@{version}".format(
            scope = id.scope,
            name = id.name,
            version = version,
        ),
    )
    package_json_output = "{scope}_{name}_{version}.json".format(
        scope = id.scope,
        name = id.name,
        version = version,
    )
    package_json = _download_and_parse_package_json(
        id = id,
        output = package_json_output,
        repository_ctx = repository_ctx,
        registry_url = registry_url,
        version = version,
    )

    # Download the source archive.
    repository_ctx.report_progress(
        "Downloading source archive for {scope}.{name}@{version}".format(
            scope = id.scope,
            name = id.name,
            version = version,
        ),
    )
    archive_checksum = _get_source_archive_checksum(package_json = package_json)
    _download_archive(
        checksum = archive_checksum,
        id = id,
        output = ".",
        repository_ctx = repository_ctx,
        registry_url = registry_url,
        version = version,
    )

    repository_ctx.report_progress(
        "Generating Bazel build files for {scope}.{name}@{version}".format(
            scope = id.scope,
            name = id.name,
            version = version,
        ),
    )

    # Remove any Bazel build files.
    repo_rules.remove_bazel_files(repository_ctx, directory)

    # Generate the WORKSPACE file
    repo_rules.write_workspace_file(repository_ctx, directory)

    # Generate the build file
    if repository_ctx.attr.resolved:
        pkg_resolved = repository_ctx.path(repository_ctx.attr.resolved)
        resolved_pkg_json = repository_ctx.read(pkg_resolved)
        resolved_pkg_map = json.decode(resolved_pkg_json)
    else:
        resolved_pkg_map = dict()

    pkg_ctx = pkg_ctxs.read(
        repository_ctx,
        directory,
        env,
        resolved_pkg_map = resolved_pkg_map,
    )

    # Replace any SCM dependencies with their registry definition if requested.
    if repository_ctx.attr.replace_scm_with_registry:
        replaced_pkg_info = _replace_scm_identities_in_pkg_info(
            pkg_info = pkg_ctx.pkg_info,
            registries = registries,
            repository_ctx = repository_ctx,
            resolved_pkg_map = resolved_pkg_map,
        )
        pkg_ctx = pkg_ctxs.new(
            pkg_info = replaced_pkg_info,
            repo_name = pkg_ctx.repo_name,
        )

    repo_rules.gen_build_files(repository_ctx, pkg_ctx)

    # Remove unused modulemaps to prevent module redefinition errors
    repo_rules.remove_modulemaps(
        repository_ctx,
        directory,
        pkg_ctx.pkg_info.targets,
    )

_REGISTRY_ATTRS = {
    "id": attr.string(
        mandatory = True,
        doc = "The package identifier.",
    ),
    "replace_scm_with_registry": attr.bool(
        default = False,
        doc = """\
When enabled replaces SCM identities in dependencies package description \
with identities from the registries.

Using this option requires that the registries provide `repositoryURLs` as \
metadata for the package.

When `True` the equivalent `--replace-scm-with-registry` option must be used \
with the Swift Package Manager CLI (or `swift_package` rule) so that the \
`resolved` file includes the version and identity information from the registry.

For more information see the \
[Swift Package Manager documentation](https://github.com/swiftlang/swift-package-manager/blob/swift-6.0.1-RELEASE/Documentation/PackageRegistry/Registry.md#45-lookup-package-identifiers-registered-for-a-url).
""",
    ),
    "resolved": attr.label(
        allow_files = [".resolved"],
        doc = """\
A `Package.resolved`, used to de-duplicate dependency identities when \
`use_registry_identity_for_scm` or `replace_scm_with_registry` is enabled.
""",
    ),
    "version": attr.string(
        mandatory = True,
        doc = "The package version.",
    ),
}

_ALL_ATTRS = dicts.add(
    _REGISTRY_ATTRS,
    repo_rules.env_attrs,
    repo_rules.swift_attrs,
    swift_package_tool_attrs.swift_package_registry,
)

registry_swift_package = repository_rule(
    implementation = _registry_swift_package_impl,
    attrs = _ALL_ATTRS,
    doc = """\
Used to download and build an external Swift package from a registry.
""",
)
