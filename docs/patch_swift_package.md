# How to Patch a Swift Package

If you come across a Swift package that you want to use but it does not build properly in Bazel, all
hope is not lost. You can patch the Swift package. This document will expalin how to do it.

## Fix the Issue and Generate a Patch File

First, you will need to figure out why the build is failing and fix it. Once you have the fix,
create a patch file using your favorite tool. For instance, if you are using `git`, you can create a
patch file by running the following:

```sh
# Assuming that your fix is in commit 33c0229, you can run the following to
# generate a patch file.
$ git format-patch -1 33c0229
```

## Copy the Patch File to Your Repository

Next, create a directory in your workspace and copy the patch file to that directory. For example,
if you are applying a patch for the `swift-cmark` package, you could do the following:

```sh
# Create a directory
$ mkdir -p third-party/swift-cmark

# Copy the patch file
$ cp /path/to/0001-fix.patch third-party/swift-cmark

# Create a BUILD file that exports the patch file
$ echo 'exports_files(["0001-Do-not-exclude-files-that-are-needed-for-compilation.patch"])' \
    > third-party/swift-cmark/BUILD
```

_NOTE: Even if you use BUILD.bazel as your preferred build file name, be sure to name this build
file BUILD. In Bazel 6.2.1 testing under `rules_bazel_integration_test`, Bazel would not recognize
the package if the file was named BUILD.bazel._

## Create a Patches YAML File

The Gazelle plugin provided by `rules_swift_package_manager` can read in a YAML file that describes
the patches that should be applied for one or more Swift packages.

Continuing our example, create a file called `swift_pkgs_patches.yml` with the following contents:

```yaml
swift-cmark:
  args: ["-p1"]
  files: ["@@//third-party/swift-cmark:0001-fix.patch"]
```

The key (e.g. `swift-cmark`) is the Swift package's identity. The supported fields are:

| YAML Field | Description                                                                                                                         |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `files`    | A list of patch files to apply.                                                                                                     |
| `args`     | Optional. A list of arguments that should be passed to the patch tool. If you are using a git patch file, be sure to include `-p1`. |
| `cmds`     | Optional. A list of Bash commands (Mac/Linux) to be applied after patches are applied.                                              |
| `win_cmds` | Optional. A list of Powershell commands (Windows) to applied after patches are applied.                                             |
| `tool`     | Optional. The tool to use to apply the patch.                                                                                       |

_REMINDER: If you are using bzlmod, use `@@` as the prefix for your patch files. Otherwise, use
`@`._

<!-- TODO: Remove swift_update_pkgs stuff and update doc. -->

## Update the `swift_update_packages` Declaration

Next, update the `swift_update_packages` declaration in the `BUILD.bazel` file at the root of your
workspace to include the `patches_yaml` attribute pointing to your patches YAML file.

```python
swift_update_packages(
    name = "swift_update_pkgs",
    gazelle = ":gazelle_bin",
    generate_swift_deps_for_workspace = False,
    patches_yaml = "swift_pkg_patches.yaml",    # <== Add this!
    update_bzlmod_stanzas = True,
)
```

## Update Your Swift Packages and Build

Now, it is time to generate some files and build.

```sh
# Resolves your Package.swift and updates the index JSON.
$ bazel run //:swift_update_pkgs

# Build/Test
$ bazel test //...
```

## Check In Your Changes

Be sure to check-in the patch file(s), patches YAML file, and any of the files that were updated by
running `//:swift_update_pkgs`.
