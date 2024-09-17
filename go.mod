module github.com/cgrindel/rules_swift_package_manager

go 1.21.4

// Workaround for inconsistent Go versions being used in rules_bazel_integration_test tests.
// toolchain go1.21.5

require (
	github.com/bazelbuild/bazel-gazelle v0.38.0
	github.com/bazelbuild/buildtools v0.0.0-20240626162158-92a716d768c0
	github.com/creasty/defaults v1.8.0
	github.com/deckarep/golang-set/v2 v2.6.0
	github.com/spf13/cobra v1.8.1
	github.com/stretchr/testify v1.9.0
	golang.org/x/exp v0.0.0-20240808152545-0cdaa3abc0fa
	golang.org/x/text v0.18.0
	gopkg.in/yaml.v3 v3.0.1
)

require (
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/spf13/pflag v1.0.5 // indirect
	golang.org/x/mod v0.20.0 // indirect
	golang.org/x/sys v0.21.0 // indirect
	golang.org/x/tools/go/vcs v0.1.0-deprecated // indirect
)
