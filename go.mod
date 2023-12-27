module github.com/cgrindel/rules_swift_package_manager

go 1.21

// Workaround for inconsistent Go versions being used in rules_bazel_integration_test tests.
// toolchain go1.21.4

require (
	github.com/bazelbuild/bazel-gazelle v0.34.0
	github.com/bazelbuild/buildtools v0.0.0-20231017121127-23aa65d4e117
	github.com/creasty/defaults v1.7.0
	github.com/deckarep/golang-set/v2 v2.6.0
	github.com/stretchr/testify v1.8.4
	golang.org/x/exp v0.0.0-20230905200255-921286631fa9
	golang.org/x/text v0.14.0
	gopkg.in/yaml.v3 v3.0.1
)

require (
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	golang.org/x/mod v0.13.0 // indirect
	golang.org/x/sys v0.13.0 // indirect
	golang.org/x/tools/go/vcs v0.1.0-deprecated // indirect
)
