package main

import (
	"bytes"
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"

	"github.com/cgrindel/swift_bazel/tools/generate_ci_workflow/internal/example"
	"github.com/cgrindel/swift_bazel/tools/generate_ci_workflow/internal/github"
	"gopkg.in/yaml.v3"
)

const intTestMatrixKey = "integration_test_matrix"

// const macOSIntTestMatrixKey = "macos_int_test_matrix"
// const ubuntuIntTestMatrixKey = "ubuntu_int_test_matrix"

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
	flag.Parse()

	// Read the workflow YAML
	workflowYAML, err := os.ReadFile(templatePath)
	if err != nil {
		return fmt.Errorf("could not read template at '%s': %w", templatePath, err)
	}
	workflow, err := github.NewWorkflowFromYAML(workflowYAML)
	if err != nil {
		return err
	}

	// Read the example JSON
	exampleJSON, err := os.ReadFile(exampleJSONPath)
	if err != nil {
		return fmt.Errorf("could not read example JSON at '%s': %w", exampleJSONPath, err)
	}
	examples, err := example.NewExamplesFromJSON(exampleJSON)
	if err != nil {
		return err
	}

	// Set up the macOS matrix
	if err := updateJob(workflow.Jobs, intTestMatrixKey, examples); err != nil {
		return err
	}

	// // Set up the macOS matrix
	// macOSExamples := filterExamplesByOS(examples, example.MacOS)
	// if err := updateJob(workflow.Jobs, macOSIntTestMatrixKey, macOSExamples); err != nil {
	// 	return err
	// }

	// // Set up the Ubuntu matrix
	// ubuntuExamples := filterExamplesByOS(examples, example.LinuxOS)
	// if err := updateJob(workflow.Jobs, ubuntuIntTestMatrixKey, ubuntuExamples); err != nil {
	// 	return err
	// }

	// Write the output file
	var outBuf bytes.Buffer
	if _, err := outBuf.WriteString(hdrMsg); err != nil {
		return err
	}
	yamlEncoder := yaml.NewEncoder(&outBuf)
	yamlEncoder.SetIndent(2)
	err = yamlEncoder.Encode(&workflow)
	if err != nil {
		return err
	}
	if err := os.WriteFile(outputPath, outBuf.Bytes(), 0666); err != nil {
		return fmt.Errorf("failed to write output YAML to '%s': %w", outputPath, err)
	}

	return nil
}

// func filterExamplesByOS(examples []example.Example, os string) []example.Example {
// 	result := make([]example.Example, 0, len(examples))
// 	for _, ex := range examples {
// 		if slices.Contains(ex.OSS, os) {
// 			result = append(result, ex)
// 		}
// 	}
// 	return result
// }

func updateJob(jobs map[string]github.Job, key string, examples []example.Example) error {
	job, ok := jobs[key]
	if !ok {
		return fmt.Errorf("did not find '%s' job", key)
	}
	matrix := job.Strategy.Matrix
	updateMatrix(&matrix, examples)
	job.Strategy.Matrix = matrix
	jobs[key] = job

	return nil
}

func updateMatrix(m *github.SBMatrixStrategy, examples []example.Example) {
	newM := github.SBMatrixStrategy{}
	for _, ex := range examples {
		for _, os := range ex.OSS {
			var runner string
			switch os {
			case "macos":
				runner = "macos-12"
			case "linux":
				runner = "ubuntu-22.04"
			}
			for _, ver := range ex.CleanVersions {
				for _, enableBzlmod := range []bool{true, false} {
					inc := github.SBMatrixInclude{
						Example:      ex.Name,
						BazelVersion: ver,
						Runner:       runner,
						EnableBzlmod: enableBzlmod,
					}
					newM.Include = append(newM.Include, inc)
				}
			}
		}
	}
	*m = newM
}

const hdrMsg = `# This file is processed by //tools/generate_ci_workflow.  Specifically, the
# matrix strategy sections for the integration test matrix jobs are updated with
# the values from //examples:json.
#
# Note:
# - Modification to values outside of the matrix strategy sections should 
#   persist.
# - Comments and custom formatting will be lost.
`
