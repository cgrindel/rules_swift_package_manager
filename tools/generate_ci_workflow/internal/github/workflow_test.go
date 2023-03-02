package github_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/tools/generate_ci_workflow/internal/github"
	"github.com/stretchr/testify/assert"
)

func TestNewWorkflowFromYAML(t *testing.T) {
	workflow, err := github.NewWorkflowFromYAML([]byte(workflowYAML))
	assert.NoError(t, err)
	assert.Equal(t, "Continuous Integration", workflow.Name)
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
        repo_name: swift_bazel
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
        repo_name: swift_bazel
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
        repo_name: swift_bazel
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
        repo_name: swift_bazel
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
