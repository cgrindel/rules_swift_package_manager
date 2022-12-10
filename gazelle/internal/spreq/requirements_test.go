package spreq_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/spreq"
	"github.com/stretchr/testify/assert"
	"gopkg.in/yaml.v3"
)

func TestRequirementsFromYaml(t *testing.T) {

	var reqs spreq.Requirements
	err := yaml.Unmarshal([]byte(requirements_yaml), &reqs)
	assert.NoError(t, err)
	assert.Equal(t, expected, reqs)
}

const requirements_yaml = `
dependencies:
- remote:
    url: "https://github.com/apple/swift-log.git"
    version: 1.4.2
- remote:
    name: example_cool_repo
    url: "https://github.com/example/not-cool-repo.git"
    revision: "8231ec25c8bc7d8802c79fd90efa09d80d04dae5"
- remote:
    name: example_another_repo
    url: "https://github.com/example/another-repo.git"
    branch: "my_branch"
- local:
    name: my_local_package
    path: "/path/to/my_local_package"
`

var expected = spreq.Requirements{
	Dependencies: []*spreq.Dependency{
		&spreq.Dependency{
			Remote: &spreq.RemoteDependency{
				URL:     "https://github.com/apple/swift-log.git",
				Version: "1.4.2",
			},
		},
		&spreq.Dependency{
			Remote: &spreq.RemoteDependency{
				Name:     "example_cool_repo",
				URL:      "https://github.com/example/not-cool-repo.git",
				Revision: "8231ec25c8bc7d8802c79fd90efa09d80d04dae5",
			},
		},
		&spreq.Dependency{
			Remote: &spreq.RemoteDependency{
				Name:   "example_another_repo",
				URL:    "https://github.com/example/another-repo.git",
				Branch: "my_branch",
			},
		},
		&spreq.Dependency{
			Local: &spreq.LocalDependency{
				Name: "my_local_package",
				Path: "/path/to/my_local_package",
			},
		},
	},
}
