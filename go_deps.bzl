"""Golang dependencies for the `rules_swift_package_manager` repository."""

load("@bazel_gazelle//:deps.bzl", "go_repository")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def swift_bazel_go_dependencies():
    """Declare the Go dependencies for `rules_swift_package_manager`."""
    maybe(
        go_repository,
        name = "com_github_bazelbuild_bazel_gazelle",
        build_external = "external",
        importpath = "github.com/bazelbuild/bazel-gazelle",
        sum = "h1:BpkUzE3H2l6buJYFTKgzVMecJimQgWwYud25qVIx0SQ=",
        version = "v0.42.0",
    )
    maybe(
        go_repository,
        name = "com_github_bazelbuild_buildtools",
        build_external = "external",
        build_naming_convention = "go_default_library",
        importpath = "github.com/bazelbuild/buildtools",
        sum = "h1:FGzENZi+SX9I7h9xvMtRA3rel8hCEfyzSixteBgn7MU=",
        version = "v0.0.0-20240918101019-be1c24cc9a44",
    )
    maybe(
        go_repository,
        name = "com_github_bazelbuild_rules_go",
        build_external = "external",
        importpath = "github.com/bazelbuild/rules_go",
        sum = "h1:/BUvuaB8MEiUA2oLPPCGtuw5V+doAYyiGTFyoSWlkrw=",
        version = "v0.50.1",
    )
    maybe(
        go_repository,
        name = "com_github_bmatcuk_doublestar_v4",
        build_external = "external",
        importpath = "github.com/bmatcuk/doublestar/v4",
        sum = "h1:fdDeAqgT47acgwd9bd9HxJRDmc9UAmPpc+2m0CXv75Q=",
        version = "v4.7.1",
    )
    maybe(
        go_repository,
        name = "com_github_cpuguy83_go_md2man_v2",
        build_external = "external",
        importpath = "github.com/cpuguy83/go-md2man/v2",
        sum = "h1:XJtiaUW6dEEqVuZiMTn1ldk455QWwEIsMIJlo5vtkx0=",
        version = "v2.0.6",
    )
    maybe(
        go_repository,
        name = "com_github_creasty_defaults",
        build_external = "external",
        importpath = "github.com/creasty/defaults",
        sum = "h1:z27FJxCAa0JKt3utc0sCImAEb+spPucmKoOdLHvHYKk=",
        version = "v1.8.0",
    )
    maybe(
        go_repository,
        name = "com_github_davecgh_go_spew",
        build_external = "external",
        importpath = "github.com/davecgh/go-spew",
        sum = "h1:vj9j/u1bqnvCEfJOwUhtlOARqs3+rkHYY13jYWTU97c=",
        version = "v1.1.1",
    )
    maybe(
        go_repository,
        name = "com_github_deckarep_golang_set_v2",
        build_external = "external",
        importpath = "github.com/deckarep/golang-set/v2",
        sum = "h1:gIloKvD7yH2oip4VLhsv3JyLLFnC0Y2mlusgcvJYW5k=",
        version = "v2.7.0",
    )
    maybe(
        go_repository,
        name = "com_github_fsnotify_fsnotify",
        build_external = "external",
        importpath = "github.com/fsnotify/fsnotify",
        sum = "h1:8JEhPFa5W2WU7YfeZzPNqzMP6Lwt7L2715Ggo0nosvA=",
        version = "v1.7.0",
    )
    maybe(
        go_repository,
        name = "com_github_golang_protobuf",
        build_external = "external",
        importpath = "github.com/golang/protobuf",
        sum = "h1:LUVKkCeviFUMKqHa4tXIIij/lbhnMbP7Fn5wKdKkRh4=",
        version = "v1.5.0",
    )
    maybe(
        go_repository,
        name = "com_github_google_go_cmp",
        build_external = "external",
        importpath = "github.com/google/go-cmp",
        sum = "h1:ofyhxvXcZhMsU5ulbFiLKl/XBFqE1GSq7atu8tAmTRI=",
        version = "v0.6.0",
    )
    maybe(
        go_repository,
        name = "com_github_inconshreveable_mousetrap",
        build_external = "external",
        importpath = "github.com/inconshreveable/mousetrap",
        sum = "h1:wN+x4NVGpMsO7ErUn/mUI3vEoE6Jt13X2s0bqwp9tc8=",
        version = "v1.1.0",
    )
    maybe(
        go_repository,
        name = "com_github_pmezard_go_difflib",
        build_external = "external",
        importpath = "github.com/pmezard/go-difflib",
        sum = "h1:4DBwDE0NGyQoBHbLQYPwSUPoCMWR5BEzIk/f1lZbAQM=",
        version = "v1.0.0",
    )
    maybe(
        go_repository,
        name = "com_github_russross_blackfriday_v2",
        build_external = "external",
        importpath = "github.com/russross/blackfriday/v2",
        sum = "h1:JIOH55/0cWyOuilr9/qlrm0BSXldqnqwMsf35Ld67mk=",
        version = "v2.1.0",
    )
    maybe(
        go_repository,
        name = "com_github_spf13_cobra",
        build_external = "external",
        importpath = "github.com/spf13/cobra",
        sum = "h1:CXSaggrXdbHK9CF+8ywj8Amf7PBRmPCOJugH954Nnlo=",
        version = "v1.9.1",
    )
    maybe(
        go_repository,
        name = "com_github_spf13_pflag",
        build_external = "external",
        importpath = "github.com/spf13/pflag",
        sum = "h1:jFzHGLGAlb3ruxLB8MhbI6A8+AQX/2eW4qeyNZXNp2o=",
        version = "v1.0.6",
    )
    maybe(
        go_repository,
        name = "com_github_stretchr_objx",
        build_external = "external",
        importpath = "github.com/stretchr/objx",
        sum = "h1:xuMeJ0Sdp5ZMRXx/aWO6RZxdr3beISkG5/G/aIRr3pY=",
        version = "v0.5.2",
    )
    maybe(
        go_repository,
        name = "com_github_stretchr_testify",
        build_external = "external",
        importpath = "github.com/stretchr/testify",
        sum = "h1:Xv5erBjTwe/5IxqUQTdXv5kgmIvbHo3QQyRwhJsOfJA=",
        version = "v1.10.0",
    )
    maybe(
        go_repository,
        name = "in_gopkg_check_v1",
        build_external = "external",
        importpath = "gopkg.in/check.v1",
        sum = "h1:yhCVgyC4o1eVCa2tZl7eS0r+SDo693bJlVdllGtEeKM=",
        version = "v0.0.0-20161208181325-20d25e280405",
    )
    maybe(
        go_repository,
        name = "in_gopkg_yaml_v3",
        build_external = "external",
        importpath = "gopkg.in/yaml.v3",
        sum = "h1:fxVm/GzAzEWqLHuvctI91KS9hhNmmWOoWu0XTYJS7CA=",
        version = "v3.0.1",
    )
    maybe(
        go_repository,
        name = "net_starlark_go",
        build_external = "external",
        importpath = "go.starlark.net",
        sum = "h1:xwwDQW5We85NaTk2APgoN9202w/l0DVGp+GZMfsrh7s=",
        version = "v0.0.0-20210223155950-e043a3d3c984",
    )
    maybe(
        go_repository,
        name = "org_golang_google_protobuf",
        build_external = "external",
        importpath = "google.golang.org/protobuf",
        sum = "h1:uNO2rsAINq/JlFpSdYEKIZ0uKD/R9cpdv0T+yoGwGmI=",
        version = "v1.33.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_exp",
        build_external = "external",
        importpath = "golang.org/x/exp",
        sum = "h1:nDVHiLt8aIbd/VzvPWN6kSOPE7+F/fNFDSXLVYkE/Iw=",
        version = "v0.0.0-20250305212735-054e65f0b394",
    )
    maybe(
        go_repository,
        name = "org_golang_x_mod",
        build_external = "external",
        importpath = "golang.org/x/mod",
        sum = "h1:ZfthKaKaT4NrhGVZHO1/WDTwGES4De8KtWO0SIbNJMU=",
        version = "v0.24.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_sync",
        build_external = "external",
        importpath = "golang.org/x/sync",
        sum = "h1:MHc5BpPuC30uJk597Ri8TV3CNZcTLu6B6z4lJy+g6Jw=",
        version = "v0.12.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_sys",
        build_external = "external",
        importpath = "golang.org/x/sys",
        sum = "h1:KHjCJyddX0LoSTb3J+vWpupP9p0oznkqVk/IfjymZbo=",
        version = "v0.26.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_text",
        build_external = "external",
        importpath = "golang.org/x/text",
        sum = "h1:D71I7dUrlY+VX0gQShAThNGHFxZ13dGLBHQLVl1mJlY=",
        version = "v0.23.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_tools",
        build_external = "external",
        importpath = "golang.org/x/tools",
        sum = "h1:0EedkvKDbh+qistFTd0Bcwe/YLh4vHwWEkiI0toFIBU=",
        version = "v0.31.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_tools_go_vcs",
        build_external = "external",
        importpath = "golang.org/x/tools/go/vcs",
        sum = "h1:cOIJqWBl99H1dH5LWizPa+0ImeeJq3t3cJjaeOWUAL4=",
        version = "v0.1.0-deprecated",
    )
