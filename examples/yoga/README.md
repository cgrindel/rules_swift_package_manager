# Yoga Example

This example demonstrates support for clang, with a root public headers search paths. For example, the file
`external/swiftpkg_yoga/yoga/module.modulemap` will be duplicated when we have both `sources: ["yoga"],` and `publicHeadersPath: ".",` in `Package.swift`. Removing duplicate from the srcs read is useful in this case.
