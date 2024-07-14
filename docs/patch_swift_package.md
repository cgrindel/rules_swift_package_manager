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

## Update your `MODULE.bazel` to Apply the Patch

Finally, configure `rules_swift_package_manager` to apply the patch to the package.

```bazel
swift_deps.configure_package(
    name = "swift-cmark",
    patch_args = ["-p1"],
    patches = [
        "//third-party/swift-cmark:0001-Do-not-exclude-files-that-are-needed-for-compilation.patch",
    ],
)
```

## Test the Patch

Now, it is time to test your patch.

```sh
# Build/Test
$ bazel test //...
```
