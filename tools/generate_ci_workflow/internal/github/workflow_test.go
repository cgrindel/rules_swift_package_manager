package github_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/generate_ci_workflow/internal/github"
	"github.com/stretchr/testify/assert"
	"gopkg.in/yaml.v3"
)

func TestFailFast(t *testing.T) {
	t.Run("is zero", func(t *testing.T) {
		tests := []struct {
			msg string
			in  github.FailFast
			exp bool
		}{
			{msg: "true", in: github.FailFast(true), exp: true},
			{msg: "false", in: github.FailFast(false), exp: false},
		}
		for _, tt := range tests {
			actual := tt.in.IsZero()
			assert.Equal(t, tt.exp, actual, tt.msg)
		}
	})
}

func TestStrategy(t *testing.T) {
	t.Run("decode YAML", func(t *testing.T) {
		tests := []struct {
			msg string
			in  string
			exp github.Strategy
		}{
			{
				msg: "without fail-fast",
				in: `
matrix:
`,
				exp: github.Strategy{FailFast: true},
			},
			{
				msg: "with fail-fast false",
				in: `
fail-fast: false
matrix:
`,
				exp: github.Strategy{FailFast: false},
			},
			{
				msg: "with fail-fast true",
				in: `
fail-fast: true
matrix:
`,
				exp: github.Strategy{FailFast: true},
			},
		}
		for _, tt := range tests {
			var actual github.Strategy
			err := yaml.Unmarshal([]byte(tt.in), &actual)
			assert.NoError(t, err)
			assert.Equal(t, tt.exp, actual, tt.msg)
		}
	})
}

func TestNewWorkflowFromYAML(t *testing.T) {
	workflow, err := github.NewWorkflowFromYAML([]byte(workflowYAML))
	assert.NoError(t, err)
	assert.Equal(t, "Continuous Integration", workflow.Name)

	// Example with strategy
	macosIntTestMatrix, ok := workflow.Jobs["macos_int_test_matrix"]
	assert.True(t, ok, "`macos_int_test_matrix` job was not found")
	assert.True(t, bool(macosIntTestMatrix.Strategy.FailFast),
		"expected strategy fail-fast to default to true")

	// Example with no strategy
	macosTidyAndTest, ok := workflow.Jobs["macos_tidy_and_test"]
	assert.True(t, ok, "`macos_tidy_and_test` job was not found")
	assert.True(t, bool(macosTidyAndTest.Strategy.FailFast),
		"expected strategy fail-fast to default to true")
}

const workflowYAML = `
name: Continuous Integration

on:
  pull_request:
    branches: [ main ]
  schedule:
    # Every day at 11:14 UTC.
    - cron: '14 11 * * *'

jobs:

  macos_tidy_and_test:
    runs-on: macos-12
    steps:
    - uses: actions/checkout@v3
    - uses: ./.github/actions/set_up_macos
      with:
        xcode_version: '14.0.1'
        repo_name: rules_swift_package_manager
    - name: Ensure everything is tidy
      shell: bash
      run: |
        bazelisk run //:tidy_check
    - name: Execute Tests
      shell: bash
      run: |
        bazelisk test //... 

  macos_int_test_matrix:
    strategy:
      matrix:
        example: []
        bazel_version: []
        include: []
    runs-on: macos-12
    steps:
    - uses: actions/checkout@v3
    - uses: ./.github/actions/set_up_macos
      with:
        xcode_version: '14.0.1'
        repo_name: rules_swift_package_manager
    - uses: ./.github/actions/test_example
      with:
        example_name: ${{ matrix.example }}
        bazel_version: ${{ matrix.bazel_version }}

  ubuntu_tidy_and_test:
    runs-on: ubuntu-22.04
    env:
      CC: clang
    steps:
    - uses: actions/checkout@v3
    - uses: ./.github/actions/set_up_ubuntu
      with:
        repo_name: rules_swift_package_manager
        ubuntu_version: "22.04"
    - name: Ensure everything is tidy
      shell: bash
      run: |
        bazelisk run //:tidy_check
    - name: Execute Tests
      shell: bash
      run: |
        bazelisk test //... 

  ubuntu_int_test_matrix:
    strategy:
      matrix:
        example: []
        bazel_version: []
        include: []
    runs-on: ubuntu-22.04
    env:
      CC: clang
    steps:
    - uses: actions/checkout@v3
    - uses: ./.github/actions/set_up_ubuntu
      with:
        repo_name: rules_swift_package_manager
        ubuntu_version: "22.04"
    - uses: ./.github/actions/test_example
      with:
        example_name: ${{ matrix.example }}
        bazel_version: ${{ matrix.bazel_version }}

  all_ci_tests:
    runs-on: ubuntu-20.04
    needs: 
    - macos_tidy_and_test
    - macos_int_test_matrix
    - ubuntu_tidy_and_test
    - ubuntu_int_test_matrix
    if: ${{ always() }}
    steps:
      - uses: cgrindel/gha_join_jobs@v1
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}

`
