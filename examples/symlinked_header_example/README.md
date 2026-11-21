# Symlinked header example

ably-cocoa ships `Source/PrivateHeaders/Ably/ARTSRWebSocket.h` as a symlink to
`Source/SocketRocket/ARTSRWebSocket.h`. Bazel sends a source symlink to remote
executors as a regular file, and executors that write each input as a separate
copy give clang two different headers. The header has no include guard, so the
Objective-C compile fails with redefinition errors.

`header_symlinks = "replace"` removes the symlink from the generated
repository and recreates it with `ctx.actions.declare_symlink`, which remote
executors receive as a symlink. `do_test` builds the package with implicit and
explicit Clang modules and checks the generated repository and output tree.

msgpack-objective-C and delta-codec-cocoa ship their public headers under
`include/` as symlinks into the package. With `header_symlinks = "replace"`,
the `PublicHeadersObjc` and `PublicHeadersSwift` targets import those headers
from separate targets. The example's `.bazelrc` sets
`--spawn_strategy=sandboxed`, so a compile that is missing the real header
behind a declared symlink fails here as it would on a remote executor.
