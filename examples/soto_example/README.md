# Soto Example

This example demonstrates support for clang, non-header files being included in other clang
source files. For example, the file
`external/swiftpkg_soto_core/Sources/CSotoExpat/xmltok.c` has a `#include "xmltok_impl.c"`. The 
file `external/swiftpkg_soto_core/Sources/CSotoExpat/xmltok_impl.c` has a comment stating 
`This file is included!`. Instead of including `xmltok_impl.c` in `srcs`, it should included in
`textual_hdrs`.
