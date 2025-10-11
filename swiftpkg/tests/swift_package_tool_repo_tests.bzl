"""Tests for `swift_package_tool_repo` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//swiftpkg/internal:swift_package_tool_repo.bzl",
    "swift_package_tool_repo_testing",
)

def _package_config_attrs_to_content_without_netrc_test(ctx):
    env = unittest.begin(ctx)

    attrs = struct(
        dependency_caching = True,
        manifest_cache = "shared",
        package = "Package.swift",
    )

    result = swift_package_tool_repo_testing.package_config_attrs_to_content(
        attrs,
    )

    # Verify netrc is not in the output when not provided
    asserts.true(
        env,
        "netrc" not in result,
        "netrc should not be present when not provided",
    )

    # Verify other attributes are present
    asserts.true(
        env,
        "dependency_caching" in result,
        "dependency_caching should be present",
    )
    asserts.true(
        env,
        "manifest_cache" in result,
        "manifest_cache should be present",
    )

    return unittest.end(env)

package_config_attrs_to_content_without_netrc_test = unittest.make(
    _package_config_attrs_to_content_without_netrc_test,
)

def _package_config_attrs_to_content_with_netrc_test(ctx):
    env = unittest.begin(ctx)

    attrs = struct(
        dependency_caching = True,
        manifest_cache = "shared",
        netrc = "//:netrc",
        package = "Package.swift",
    )

    result = swift_package_tool_repo_testing.package_config_attrs_to_content(
        attrs,
    )

    # Verify netrc is included in the output
    asserts.true(
        env,
        "netrc" in result,
        "netrc should be present when provided",
    )
    asserts.true(
        env,
        '"//:netrc"' in result,
        "netrc value should be properly quoted",
    )

    return unittest.end(env)

package_config_attrs_to_content_with_netrc_test = unittest.make(
    _package_config_attrs_to_content_with_netrc_test,
)

def _netrc_in_attrs_content_test(ctx):
    env = unittest.begin(ctx)

    # Test that _package_config_attrs_to_content includes netrc when
    # present. The repository implementation will later filter and
    # replace this
    attrs = struct(
        netrc = "//:.netrc",
        package = "Package.swift",
        dependency_caching = False,
    )

    attrs_content = swift_package_tool_repo_testing.package_config_attrs_to_content(
        attrs,
    )

    # The raw attrs_content should contain netrc
    asserts.true(
        env,
        "netrc" in attrs_content,
        "netrc should be in attrs_content",
    )

    # Simulate the filtering logic from swift_package_tool_repo_impl
    # (line 45)
    attrs_lines = [
        line
        for line in attrs_content.split("\n")
        if "netrc =" not in line
    ]
    filtered_attrs = "\n".join(attrs_lines)

    # After filtering, netrc should be removed
    asserts.true(
        env,
        "netrc" not in filtered_attrs,
        "netrc should be filtered out",
    )

    return unittest.end(env)

netrc_in_attrs_content_test = unittest.make(_netrc_in_attrs_content_test)

def _netrc_with_empty_attrs_test(ctx):
    env = unittest.begin(ctx)

    attrs = struct(
        netrc = "//:.netrc",
        package = "Package.swift",
    )

    result = swift_package_tool_repo_testing.package_config_attrs_to_content(
        attrs,
    )

    # Verify netrc is present even when other optional attrs are not
    asserts.true(env, "netrc" in result, "netrc should be present")
    asserts.true(env, len(result) > 0, "result should not be empty")

    return unittest.end(env)

netrc_with_empty_attrs_test = unittest.make(_netrc_with_empty_attrs_test)

def _netrc_filtering_and_replacement_test(ctx):
    env = unittest.begin(ctx)

    # Test the complete flow: attrs_content generation, filtering, and
    # replacement. This simulates what happens in
    # _swift_package_tool_repo_impl
    attrs = struct(
        netrc = "@myworkspace//.netrc",
        package = "Package.swift",
        dependency_caching = True,
        manifest_cache = "shared",
    )

    # Step 1: Get attrs content (this includes netrc as-is)
    attrs_content = swift_package_tool_repo_testing.package_config_attrs_to_content(
        attrs,
    )

    # Step 2: Filter out netrc (simulates line 45 of
    # swift_package_tool_repo.bzl)
    attrs_lines = [
        line
        for line in attrs_content.split("\n")
        if "netrc =" not in line
    ]
    filtered_attrs = "\n".join(attrs_lines)

    # Step 3: Add modified netrc pointing to local copy (simulates lines
    # 43, 48-51)
    netrc_attr = '    netrc = ":.netrc",'
    final_attrs_parts = [filtered_attrs]
    if netrc_attr:
        final_attrs_parts.append(netrc_attr)
    final_attrs_content = "\n".join([p for p in final_attrs_parts if p])

    # Verify the final result
    asserts.true(
        env,
        "netrc" in final_attrs_content,
        "netrc should be in final content",
    )
    asserts.true(
        env,
        ":.netrc" in final_attrs_content,
        "netrc should point to local copy",
    )
    asserts.true(
        env,
        "@myworkspace" not in final_attrs_content,
        "original netrc path should be replaced",
    )
    asserts.true(
        env,
        "dependency_caching" in final_attrs_content,
        "other attrs should be preserved",
    )
    asserts.true(
        env,
        "manifest_cache" in final_attrs_content,
        "other attrs should be preserved",
    )

    # Verify netrc appears exactly once in final output
    netrc_count = final_attrs_content.count("netrc =")
    asserts.equals(
        env,
        1,
        netrc_count,
        "netrc should appear exactly once after filtering and replacement",
    )

    return unittest.end(env)

netrc_filtering_and_replacement_test = unittest.make(
    _netrc_filtering_and_replacement_test,
)

def swift_package_tool_repo_test_suite():
    return unittest.suite(
        "swift_package_tool_repo_tests",
        package_config_attrs_to_content_without_netrc_test,
        package_config_attrs_to_content_with_netrc_test,
        netrc_in_attrs_content_test,
        netrc_with_empty_attrs_test,
        netrc_filtering_and_replacement_test,
    )
