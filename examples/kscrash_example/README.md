# KSCrash with patch to explicitly link against zlib

This example demonstrates using KSCrash package which implicitly depends on `zlib` but is not explicitly linked in `Package.swift` manifest. It also demonstrates that rules_swift_package_manager supports `.def` files in clang targets.

## Notes

* Find how to apply the patch in `MODULE.bazel`
