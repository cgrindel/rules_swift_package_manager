# Example with Interesting Dependencies

This example demonstrates how to declare dependent Swift packages with unique or non-standard
characteristics.


## libwebp-Xcode

The [libwebp-Xcode](https://github.com/SDWebImage/libwebp-Xcode) package is interesting for the
following reasons.


### Package Name Does Not Match the Repository Name

The name of the package in the `Package.swift` (`libwebp`) does not match the name of the Git
repository (`libwebp-Xcode`). Since `rules_spm` is unable to derive the package name from the URL,
we must specify the correct package name in the `spm_pkg` declaration.

```python
        spm_pkg(
            # Need to specify for the package because the URL basename does not
            # match the package name in the Package.swift.
            name = "libwebp",
            exact_version = "1.2.1",
            products = ["libwebp"],
            url = "https://github.com/SDWebImage/libwebp-Xcode.git",
        ),
```


### Clang Headers in Nested Include Directory

The package contains a clang target. The public header files for the target are located in a
directory that is nested under the `include` directory. The header discovery logic for `rules_spm`
will include all of the header files that reside directly in the `include` directory or in any of
its subdirectories.
