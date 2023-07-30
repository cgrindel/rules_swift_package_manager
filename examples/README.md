# Examples for `rules_swift_package_manager`

## Adding an example

This repository includes a `//tools/create_example` utility that creates a minimal `swift_binary`
example. Run the following to get started:

```sh
$ bazel run //tools/create_example -- <example_name>
```

For example to create an example workspace called `foo` under the `examples/foo_example` directory,
run the following.

```sh
$ bazel run //tools/create_example -- foo
```

This will create the example workspace, run some tools to update the Swift packages, generate build
files, build and run the Swift binary.

After the example has been created, you will be instructed to add the new example to the
`examples/example_infos.bzl` file and run `bazel run //:tidy` in the parent workspace.
