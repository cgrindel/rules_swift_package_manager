package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"

	"github.com/cgrindel/swift_bazel/tools/generate_ci_workflow/internal/example"
	"github.com/cgrindel/swift_bazel/tools/generate_ci_workflow/internal/github"
	"golang.org/x/exp/slices"
)

const macOSIntTestMatrixKey = "macos_int_test_matrix"
const ubuntuIntTestMatrixKey = "ubuntu_int_test_matrix"

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()
	if err := run(ctx, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(ctx context.Context, stderr *os.File) error {
	var (
		templatePath    string
		exampleJSONPath string
		outputPath      string
	)
	flag.StringVar(&templatePath, "template", "", "path to the template file")
	flag.StringVar(&exampleJSONPath, "example_json", "", "path to the examples JSON file")
	flag.StringVar(&outputPath, "output", "", "path to the output file")
	flag.Usage = func() {
		fmt.Fprint(flag.CommandLine.Output(), `usage: bazel run //tools/generate_ci_workflow -- -template <template_path> -example_json <example_json> -output <output>

This utility generates a new GitHub actions workflow file for this project.

`)
		flag.PrintDefaults()
	}

	// Read the workflow YAML
	workflowYAML, err := os.ReadFile(templatePath)
	if err != nil {
		return err
	}
	workflow, err := github.NewWorkflowFromYAML(workflowYAML)
	if err != nil {
		return err
	}

	// Read the example JSON
	exampleJSON, err := os.ReadFile(exampleJSONPath)
	if err != nil {
		return err
	}
	examples, err := example.NewExamplesFromJSON(exampleJSON)
	if err != nil {
		return err
	}

	// Set up the macOS matrix
	macosIntTestMatrix, ok := workflow.Jobs[macOSIntTestMatrixKey]
	if !ok {
		return fmt.Errorf("Did not find '%' job.", macOSIntTestMatrixKey)
	}
	macOSExamples := filterExamplesByOS(examples, example.MacOS)
	updateMatrix(&macosIntTestMatrix, macOSExamples)

	// Set up the Ubuntu matrix
	ubuntuIntTestMatrix, ok := workflow.Jobs[ubuntuIntTestMatrixKey]
	if !ok {
		return fmt.Errorf("Did not find '%' job.", ubuntuIntTestMatrixKey)
	}
	ubuntuExamples := filterExamplesByOS(examples, example.LinuxOS)
	updateMatrix(&ubuntuIntTestMatrix, ubuntuExamples)

	return nil
}

func filterExamplesByOS(examples []example.Example, os string) []example.Example {
	result := make([]example.Example, 0, len(examples))
	for _, ex := range examples {
		if slices.Contains(ex.OSS, os) {
			result = append(result, ex)
		}
	}
	return result
}

func updateMatrix(j *github.Job, examples []example.Example) {
	include := j.Strategy.Matrix.Include
	for _, ex := range examples {
		for _, ver := range ex.Versions {
			inc := github.SBMatrixInclude{Example: ex.Name, BazelVersion: ver}
			include = append(include, inc)
		}
	}
}
