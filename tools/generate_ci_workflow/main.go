package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
)

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
	)
	flag.StringVar(&templatePath, "template", "", "path to the template file")
	flag.StringVar(&exampleJSONPath, "example_json", "", "path to the examples JSON file")
	flag.Usage = func() {
		fmt.Fprint(flag.CommandLine.Output(), `usage: bazel run //tools/generate_ci_workflow -- -template <template_path> -example_json <example_json>

This utility generates a new GitHub actions workflow file for this project.

`)
		flag.PrintDefaults()
	}

	return nil
}
