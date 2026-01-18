# Release Process for `rules_spm`

The release process for this repository is implemented using GitHub Actions and the [bzlrelease
macros](https://github.com/cgrindel/bazel-starlib/tree/main/bzlrelease). This document describes how
to create a release.

## How to Create a Release

Once all of the code for a release has been merged to main, the release process can be started by
executing the `//release:create` target specifying the desired release tag (e.g. v1.2.3). To create
a release tagged with `v0.1.4`, one would run the following:

```sh
# Launch release GitHub Actions release workflow for v0.1.4
$ bazel run //release:create -- v0.1.4
```

This will launch the [release workflow](.github/workflows/create_release.yml). The workflow performs
the following steps:

1. Creates the specified tag at the HEAD of the main branch.
2. Generates release notes.
3. Creates a GitHub release.
4. Updates the `README.md` with the latest workspace snippet information.
5. Creates a PR with the updated `README.md` configured to auto-merge if all the checks pass.
6. Triggers the [Publish to BCR workflow](.github/workflows/publish_to_bcr.yml) which automatically
   submits the release to the Bazel Central Registry.

There are two ways that this process could fail. First, if an improperly formatted release tag is
specified, the release workflow will fail. Be sure to prefix the release tag with `v`. Second, the
PR that contains the updates to the README.md file could fail if the PR cannot be automatically
merged.

## Other Scenarios

### Testing Changes to the Release Process

If you are testing changes to the release workflows, you should make the desired changes in a
branch, push the branch to `origin`, and then execute the `//release:create` target with the `--ref
<branch_name>`. For instance, if the remote branch name is `fixes_for_release` and the next release
is `v1.2.3`, then you would run the following:

```sh
$ bazel run //release:create -- v1.2.3 --ref fixes_for_release
```

### Rerunning a Failed Release

If you executed a release workflow and it failed without creating the release, you can rerun the
workflow with the same tag adding the `--reset_tag` option. For instance, if you need to rerun the
release for `v1.2.3`, you would run the following:

```sh
$ bazel run //release:create -- v1.2.3 --reset_tag
```

If the failure occurred after the creation of the release, you have two options:

1. Delete the release and run the release again with the `--reset_tag`; OR
2. Create a new release with a new tag.

One should be very careful with option #1 as clients may see the failed release and attempt to use
it. Option #2 is always the safest path.

## Bazel Central Registry (BCR) Publication

The repository uses the [publish-to-bcr GitHub workflow](https://github.com/bazel-contrib/publish-to-bcr)
to automatically submit releases to the Bazel Central Registry.

### Automatic Publication

When a GitHub release is published, the [Publish to BCR workflow](.github/workflows/publish_to_bcr.yml)
is automatically triggered. This workflow:

1. Creates a pull request in the [Bazel Central Registry](https://github.com/bazelbuild/bazel-central-registry)
   via the fork at `cgrindel/bazel-central-registry`.
2. Uses the BCR configuration files in the `.bcr/` directory to populate module metadata.
3. Runs presubmit tests defined in `.bcr/presubmit.yml` to verify the release.

### Manual Publication

If you need to manually trigger BCR publication for a specific release, you can do so using the
GitHub Actions UI:

1. Go to the [Publish to BCR workflow](../../actions/workflows/publish_to_bcr.yml) in GitHub Actions.
2. Click "Run workflow".
3. Enter the release tag (e.g., `v1.2.3`).
4. Click "Run workflow" to start the publication process.

### BCR Configuration

The BCR publication process is configured through files in the `.bcr/` directory:

- `config.yml` - Specifies the fixed releaser information
- `presubmit.yml` - Defines tests that run during BCR presubmit validation
- `metadata.template.json` - Template for module metadata
- `source.template.json` - Template for source archive information
