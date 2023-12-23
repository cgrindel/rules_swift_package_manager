"""Golang dependencies for the `rules_swift_package_manager` repository."""

load("@bazel_gazelle//:deps.bzl", "go_repository")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def swift_bazel_go_dependencies():
    """Declare the Go dependencies for `rules_swift_package_manager`."""
    maybe(
        go_repository,
        name = "co_honnef_go_tools",
        build_external = "external",
        importpath = "honnef.co/go/tools",
        sum = "h1:/hemPrYIhOhy8zYrNj+069zDB68us2sMGsfkFJO0iZs=",
        version = "v0.0.0-20190523083050-ea95bdfd59fc",
    )
    maybe(
        go_repository,
        name = "com_github_bazelbuild_bazel_gazelle",
        build_external = "external",
        importpath = "github.com/bazelbuild/bazel-gazelle",
        sum = "h1:YHkwssgvCXDRU7sLCq1kGqaGYO9pKNR1Wku7UT2LhoY=",
        version = "v0.34.0",
    )
    maybe(
        go_repository,
        name = "com_github_bazelbuild_buildtools",
        build_external = "external",
        build_naming_convention = "go_default_library",
        importpath = "github.com/bazelbuild/buildtools",
        sum = "h1:VUHCI4QRifAGYsbVJYqJndLf7YqV12YthB+PLFsEKqo=",
        version = "v0.0.0-20231017121127-23aa65d4e117",
    )
    maybe(
        go_repository,
        name = "com_github_bazelbuild_rules_go",
        build_external = "external",
        importpath = "github.com/bazelbuild/rules_go",
        sum = "h1:aY2smc3JWyUKOjGYmOKVLX70fPK9ON0rtwQojuIeUHc=",
        version = "v0.42.0",
    )
    maybe(
        go_repository,
        name = "com_github_bmatcuk_doublestar_v4",
        build_external = "external",
        importpath = "github.com/bmatcuk/doublestar/v4",
        sum = "h1:FH9SifrbvJhnlQpztAx++wlkk70QBf0iBWDwNy7PA4I=",
        version = "v4.6.1",
    )
    maybe(
        go_repository,
        name = "com_github_burntsushi_toml",
        build_external = "external",
        importpath = "github.com/BurntSushi/toml",
        sum = "h1:WXkYYl6Yr3qBf1K79EBnL4mak0OimBfB0XUf9Vl28OQ=",
        version = "v0.3.1",
    )
    maybe(
        go_repository,
        name = "com_github_census_instrumentation_opencensus_proto",
        build_external = "external",
        importpath = "github.com/census-instrumentation/opencensus-proto",
        sum = "h1:glEXhBS5PSLLv4IXzLA5yPRVX4bilULVyxxbrfOtDAk=",
        version = "v0.2.1",
    )
    maybe(
        go_repository,
        name = "com_github_chzyer_logex",
        build_external = "external",
        importpath = "github.com/chzyer/logex",
        sum = "h1:Swpa1K6QvQznwJRcfTfQJmTE72DqScAa40E+fbHEXEE=",
        version = "v1.1.10",
    )
    maybe(
        go_repository,
        name = "com_github_chzyer_readline",
        build_external = "external",
        importpath = "github.com/chzyer/readline",
        sum = "h1:fY5BOSpyZCqRo5OhCuC+XN+r/bBCmeuuJtjz+bCNIf8=",
        version = "v0.0.0-20180603132655-2972be24d48e",
    )
    maybe(
        go_repository,
        name = "com_github_chzyer_test",
        build_external = "external",
        importpath = "github.com/chzyer/test",
        sum = "h1:q763qf9huN11kDQavWsoZXJNW3xEE4JJyHa5Q25/sd8=",
        version = "v0.0.0-20180213035817-a1ea475d72b1",
    )
    maybe(
        go_repository,
        name = "com_github_client9_misspell",
        build_external = "external",
        importpath = "github.com/client9/misspell",
        sum = "h1:ta993UF76GwbvJcIo3Y68y/M3WxlpEHPWIGDkJYwzJI=",
        version = "v0.3.4",
    )
    maybe(
        go_repository,
        name = "com_github_creasty_defaults",
        build_external = "external",
        importpath = "github.com/creasty/defaults",
        sum = "h1:eNdqZvc5B509z18lD8yc212CAqJNvfT1Jq6L8WowdBA=",
        version = "v1.7.0",
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
        name = "com_github_envoyproxy_go_control_plane",
        build_external = "external",
        importpath = "github.com/envoyproxy/go-control-plane",
        sum = "h1:4cmBvAEBNJaGARUEs3/suWRyfyBfhf7I60WBZq+bv2w=",
        version = "v0.9.1-0.20191026205805-5f8ba28d4473",
    )
    maybe(
        go_repository,
        name = "com_github_envoyproxy_protoc_gen_validate",
        build_external = "external",
        importpath = "github.com/envoyproxy/protoc-gen-validate",
        sum = "h1:EQciDnbrYxy13PgWoY8AqoxGiPrpgBZ1R8UNe3ddc+A=",
        version = "v0.1.0",
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
        name = "com_github_golang_glog",
        build_external = "external",
        importpath = "github.com/golang/glog",
        sum = "h1:VKtxabqXZkF25pY9ekfRL6a582T4P37/31XEstQ5p58=",
        version = "v0.0.0-20160126235308-23def4e6c14b",
    )
    maybe(
        go_repository,
        name = "com_github_golang_mock",
        build_external = "external",
        importpath = "github.com/golang/mock",
        sum = "h1:G5FRp8JnTd7RQH5kemVNlMeyXQAztQ3mOWV95KxsXH8=",
        version = "v1.1.1",
    )
    maybe(
        go_repository,
        name = "com_github_golang_protobuf",
        build_external = "external",
        importpath = "github.com/golang/protobuf",
        sum = "h1:JjCZWpVbqXDqFVmTfYWEVTMIYrL/NPdPSCHPJ0T/raM=",
        version = "v1.4.3",
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
        name = "com_github_pmezard_go_difflib",
        build_external = "external",
        importpath = "github.com/pmezard/go-difflib",
        sum = "h1:4DBwDE0NGyQoBHbLQYPwSUPoCMWR5BEzIk/f1lZbAQM=",
        version = "v1.0.0",
    )
    maybe(
        go_repository,
        name = "com_github_prometheus_client_model",
        build_external = "external",
        importpath = "github.com/prometheus/client_model",
        sum = "h1:gQz4mCbXsO+nc9n1hCxHcGA3Zx3Eo+UHZoInFGUIXNM=",
        version = "v0.0.0-20190812154241-14fe0d1b01d4",
    )
    maybe(
        go_repository,
        name = "com_github_stretchr_objx",
        build_external = "external",
        importpath = "github.com/stretchr/objx",
        sum = "h1:1zr/of2m5FGMsad5YfcqgdqdWrIhu+EBEJRhR1U7z/c=",
        version = "v0.5.0",
    )
    maybe(
        go_repository,
        name = "com_github_stretchr_testify",
        build_external = "external",
        importpath = "github.com/stretchr/testify",
        sum = "h1:CcVxjf3Q8PM0mHUKJCdn+eZZtm5yQwehR5yeSVQQcUk=",
        version = "v1.8.4",
    )
    maybe(
        go_repository,
        name = "com_google_cloud_go",
        build_external = "external",
        importpath = "cloud.google.com/go",
        sum = "h1:e0WKqKTd5BnrG8aKH3J3h+QvEIQtSUcf2n5UZ5ZgLtQ=",
        version = "v0.26.0",
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
        name = "org_golang_google_appengine",
        build_external = "external",
        importpath = "google.golang.org/appengine",
        sum = "h1:/wp5JvzpHIxhs/dumFmF7BXTf3Z+dd4uXta4kVyO508=",
        version = "v1.4.0",
    )
    maybe(
        go_repository,
        name = "org_golang_google_genproto",
        build_external = "external",
        importpath = "google.golang.org/genproto",
        sum = "h1:+kGHl1aib/qcwaRi1CbqBZ1rk19r85MNUf8HaBghugY=",
        version = "v0.0.0-20200526211855-cb27e3aa2013",
    )
    maybe(
        go_repository,
        name = "org_golang_google_grpc",
        build_external = "external",
        importpath = "google.golang.org/grpc",
        sum = "h1:rRYRFMVgRv6E0D70Skyfsr28tDXIuuPZyWGMPdMcnXg=",
        version = "v1.27.0",
    )
    maybe(
        go_repository,
        name = "org_golang_google_protobuf",
        build_external = "external",
        importpath = "google.golang.org/protobuf",
        sum = "h1:Ejskq+SyPohKW+1uil0JJMtmHCgJPJ/qWTxr8qp+R4c=",
        version = "v1.25.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_crypto",
        build_external = "external",
        importpath = "golang.org/x/crypto",
        sum = "h1:VklqNMn3ovrHsnt90PveolxSbWFaJdECFbxSq0Mqo2M=",
        version = "v0.0.0-20190308221718-c2843e01d9a2",
    )
    maybe(
        go_repository,
        name = "org_golang_x_exp",
        build_external = "external",
        importpath = "golang.org/x/exp",
        sum = "h1:GoHiUyI/Tp2nVkLI2mCxVkOjsbSXD66ic0XW0js0R9g=",
        version = "v0.0.0-20230905200255-921286631fa9",
    )
    maybe(
        go_repository,
        name = "org_golang_x_lint",
        build_external = "external",
        importpath = "golang.org/x/lint",
        sum = "h1:XQyxROzUlZH+WIQwySDgnISgOivlhjIEwaQaJEJrrN0=",
        version = "v0.0.0-20190313153728-d0100b6bd8b3",
    )
    maybe(
        go_repository,
        name = "org_golang_x_mod",
        build_external = "external",
        importpath = "golang.org/x/mod",
        sum = "h1:I/DsJXRlw/8l/0c24sM9yb0T4z9liZTduXvdAWYiysY=",
        version = "v0.13.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_net",
        build_external = "external",
        importpath = "golang.org/x/net",
        sum = "h1:oWX7TPOiFAMXLq8o0ikBYfCJVlRHBcsciT5bXOrH628=",
        version = "v0.0.0-20190311183353-d8887717615a",
    )
    maybe(
        go_repository,
        name = "org_golang_x_oauth2",
        build_external = "external",
        importpath = "golang.org/x/oauth2",
        sum = "h1:vEDujvNQGv4jgYKudGeI/+DAX4Jffq6hpD55MmoEvKs=",
        version = "v0.0.0-20180821212333-d2e6202438be",
    )
    maybe(
        go_repository,
        name = "org_golang_x_sync",
        build_external = "external",
        importpath = "golang.org/x/sync",
        sum = "h1:zxkM55ReGkDlKSM+Fu41A+zmbZuaPVbGMzvvdUPznYQ=",
        version = "v0.4.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_sys",
        build_external = "external",
        importpath = "golang.org/x/sys",
        sum = "h1:Af8nKPmuFypiUBjVoU9V20FiaFXOcuZI21p0ycVYYGE=",
        version = "v0.13.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_text",
        build_external = "external",
        importpath = "golang.org/x/text",
        sum = "h1:ScX5w1eTa3QqT8oi6+ziP7dTV1S2+ALU0bI+0zXKWiQ=",
        version = "v0.14.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_tools",
        build_external = "external",
        importpath = "golang.org/x/tools",
        sum = "h1:Iey4qkscZuv0VvIt8E0neZjtPVQFSc870HQ448QgEmQ=",
        version = "v0.13.0",
    )
    maybe(
        go_repository,
        name = "org_golang_x_tools_go_vcs",
        build_external = "external",
        importpath = "golang.org/x/tools/go/vcs",
        sum = "h1:cOIJqWBl99H1dH5LWizPa+0ImeeJq3t3cJjaeOWUAL4=",
        version = "v0.1.0-deprecated",
    )
    maybe(
        go_repository,
        name = "org_golang_x_xerrors",
        build_external = "external",
        importpath = "golang.org/x/xerrors",
        sum = "h1:go1bK/D/BFZV2I8cIQd1NKEZ+0owSTG1fDTci4IqFcE=",
        version = "v0.0.0-20200804184101-5ec99f83aff1",
    )
