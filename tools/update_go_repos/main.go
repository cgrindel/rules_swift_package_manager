package main

import (
	"context"
	"flag"
	"fmt"
	"log"
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
	}
	if buildExternal != "" {
		args = append(args, fmt.Sprintf("-build_external=%s", buildExternal))
	}
	// DEBUG BEGIN
	dbgCmd := exec.CommandContext(ctx, "env")
	if dbgOut, err := dbgCmd.CombinedOutput(); err != nil {
		log.Printf("*** CHUCK:  err: %+#v", err)
	} else {
		log.Printf("*** CHUCK:  dbgOut:\n%s", string(dbgOut))
	}
	log.Printf("*** CHUCK: bazel args: ")
	for idx, item := range args {
		log.Printf("*** CHUCK %d: %+#v", idx, item)
	}
	// DEBUG END
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

	return nil
}
