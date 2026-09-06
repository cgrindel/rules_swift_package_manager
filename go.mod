module github.com/cgrindel/rules_swift_package_manager

go 1.26.0

toolchain go1.27.1

// Workaround for inconsistent Go versions being used in rules_bazel_integration_test tests.
// toolchain go1.21.5

require (
	github.com/bazelbuild/bazel-gazelle v0.50.0
	github.com/bazelbuild/buildtools v0.0.0-20250930140053-2eb4fccefb52
	github.com/creasty/defaults v1.8.0
	github.com/deckarep/golang-set/v2 v2.9.0
	github.com/spf13/cobra v1.10.2
	github.com/stretchr/testify v1.12.1
	golang.org/x/exp v0.0.0-20260824195058-e88cd73687aa
	golang.org/x/text v0.41.0
	gopkg.in/yaml.v3 v3.0.1
)

require (
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/spf13/pflag v1.0.9 // indirect
	go.mongodb.org/mongo-driver v1.17.4 // indirect
	go.yaml.in/yaml/v3 v3.0.5 // indirect
	golang.org/x/mod v0.40.0 // indirect
	golang.org/x/sys v0.30.0 // indirect
	golang.org/x/tools/go/vcs v0.1.0-deprecated // indirect
)
