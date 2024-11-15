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
        sum = "h1:SAYys3KRG5i3KTgQAvO423bLT1rQMSgqEKReMkM/CW0=",
        version = "v0.40.0",
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
        sum = "h1:wfIWP927BUkWJb2NmU/kNDYIBTh/ziUX91+lVfRxZq4=",
        version = "v2.0.4",
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
        sum = "h1:XfcQbWM1LlMB8BsJ8N9vW5ehnnPVIw0je80NsVHagjM=",
        version = "v2.6.0",
    )
    maybe(
        go_repository,
        name = "com_github_fsnotify_fsnotify",
        build_external = "external",
        importpath = "github.com/fsnotify/fsnotify",
        sum = "h1:dAwr6QBTBZIkG8roQaJjGof0pp0EeF+tNV7YBP3F/8M=",
        version = "v1.8.0",
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
        sum = "h1:e5/vxKd/rZsfSJMUX1agtjeTDf+qv1/JdBF8gg5k9ZM=",
        version = "v1.8.1",
    )
    maybe(
        go_repository,
        name = "com_github_spf13_pflag",
        build_external = "external",
        importpath = "github.com/spf13/pflag",
        sum = "h1:iy+VFUOCP1a+8yFto/drg2CJ5u0yRoB7fZw3DKv/JXA=",
        version = "v1.0.5",
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
        sum = "h1:HtqpIVDClZ4nwg75+f6Lvsy/wHu+3BoSGCbBAcpTsTg=",
        version = "v1.9.0",
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
        sum = "h1:ELnwvuAXPNtPk1TJRuGkI9fDTwym6AYBu0qzT8AcHdI=",
        version = "v0.0.0-20240808152545-0cdaa3abc0fa",
    )
    maybe(
        go_repository,
        name = "org_golang_x_mod",
        build_external = "external",
        importpath = "golang.org/x/mod",
        sum = "h1:vvrHzRwRfVKSiLrG+d4FMl/Qi4ukBCE6kZlTUkDYRT0=",
        version = "v0.21.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_sync",
        build_external = "external",
        importpath = "golang.org/x/sync",
        sum = "h1:3NFvSEYkUoMifnESzZl15y791HH1qU2xm6eCJU5ZPXQ=",
        version = "v0.8.0",
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
        sum = "h1:kTxAhCbGbxhK0IwgSKiMO5awPoDQ0RpfiVYBfK860YM=",
        version = "v0.19.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_tools",
        build_external = "external",
        importpath = "golang.org/x/tools",
        sum = "h1:J1shsA93PJUEVaUSaay7UXAyE8aimq3GW0pjlolpa24=",
        version = "v0.24.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_tools_go_vcs",
        build_external = "external",
        importpath = "golang.org/x/tools/go/vcs",
        sum = "h1:cOIJqWBl99H1dH5LWizPa+0ImeeJq3t3cJjaeOWUAL4=",
        version = "v0.1.0-deprecated",
    )
