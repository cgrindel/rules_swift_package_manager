package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path"
)

const maybeRuleKind = "maybe"

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()
	if err := run(ctx, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(ctx context.Context, stderr *os.File) error {
	var repoRoot string
	var fromFile string
	var goDepsFile string
	var macroName string
	var buildExternal string
	var gazelleBinTarget string
	flag.StringVar(&repoRoot, "repo_root", os.Getenv("BUILD_WORKSPACE_DIRECTORY"), "root directory of Gazelle repo")
	flag.StringVar(&fromFile, "from_file", "go.mod", "Go module file")
	flag.StringVar(&goDepsFile, "go_deps_file", "go_deps.bzl", "file where to write go_repository declarations")
	flag.StringVar(&macroName, "macro_name", "", "the name of the macro that will contain the go_repository declarations")
	flag.StringVar(&buildExternal, "build_external", "external", "the build external value to be added to the go_repository declarations")
	flag.StringVar(&gazelleBinTarget, "gazelle_bin_target", "//:gazelle_bin", "the target for the gazelle_binary")
	flag.Usage = func() {
		fmt.Fprint(flag.CommandLine.Output(), `usage: bazel run //tools/update_go_repos

This utility updates the Go repositories for this repo wrapping them in 'maybe' declarations.

`)
		flag.PrintDefaults()
	}
	flag.Parse()

	if gazelleBinTarget == "" {
		return fmt.Errorf("a gazelle_bin_target must be specified")
	}
	if macroName == "" {
		return fmt.Errorf("a macro_name must be specified")
	}

	depsPath := path.Join(repoRoot, goDepsFile)

	// Remove the declarations from the macro file
	if err := removeGoDeclarations(depsPath, macroName); err != nil {
		return fmt.Errorf("failed removing Go declarations from deps file: %w", err)
	}

	// Update the repos
	args := []string{
		"run", gazelleBinTarget, "--", "update-repos",
		fmt.Sprintf("-from_file=%s", fromFile),
		fmt.Sprintf("-to_macro=%s%%%s", goDepsFile, macroName),
		// Need to tell Gazelle to run as if it is in bzlmod mode. It does not figure it out
		// properly when we run it from inside this binary.
		// Related to https://github.com/bazelbuild/bazel-gazelle/pull/1589.
		"-bzlmod",
	}
	if buildExternal != "" {
		args = append(args, fmt.Sprintf("-build_external=%s", buildExternal))
	}
	cmd := exec.CommandContext(ctx, "bazel", args...)
	cmd.Dir = repoRoot
	if out, err := cmd.CombinedOutput(); err != nil {
		fmt.Println(string(out))
		return err
	}

	// update deps
	if err := updateDepsBzlWithRules(depsPath, macroName); err != nil {
		return fmt.Errorf("failed updating deps file with maybe declarations: %w", err)
	}

	// GH557: HACK Revert changes made to the WORKSPACE.
	// This hack can be removed post v0.32.0. We are waiting for the following fix to be released:
	// https://github.com/bazelbuild/bazel-gazelle/pull/1589
	wkspFile := path.Join(repoRoot, "WORKSPACE")
	wkspContents := "# Intentionally blank: use bzlmod\n"
	if err := os.WriteFile(wkspFile, []byte(wkspContents), 0666); err != nil {
		return fmt.Errorf("failed reverting changes to the WORKSPACE file: %w", err)
	}

	return nil
}
