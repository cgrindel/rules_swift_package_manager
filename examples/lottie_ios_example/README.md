# lottie_ios Example

This example was copied from [the example in
lottie-spm](https://github.com/airbnb/lottie-spm/tree/main/Example/iOS). It was modified slightly to
ensure that it built and launched successfully.

## Why is this interesting?

The [lottie-spm](https://github.com/airbnb/lottie-spm) downloads a dynamic xcframework. This
exercises the xcframework detection logic in `rules_swift_package_manager`.
