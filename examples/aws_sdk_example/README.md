# AWS SDK Swift Example

This example demonstrates building a Swift application that uses the AWS SDK for Swift.

## Building

```bash
bazel build //:AwsSdkExample
```

## Running

```bash
bazel run //:AwsSdkExample
```

Expected output:
```
AWS SDK Swift S3 client created successfully
```

## What This Tests

This example verifies that rules_swift_package_manager can successfully build aws-sdk-swift, which depends on:
- aws-crt-swift (complex C dependencies with inline headers, excluded directories, and system frameworks)
- Multiple Swift packages with various dependency patterns
- Transitive C library dependencies with framework auto-detection

The successful build demonstrates that all the fixes for complex C dependencies work correctly with a real-world, complex Swift package.
