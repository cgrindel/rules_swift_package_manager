package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path"

	"github.com/bazelbuild/bazel-gazelle/rule"
	bzl "github.com/bazelbuild/buildtools/build"
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
	_tmpBzl := "tmp.bzl"
	tmpBzlPath := path.Join(repoRoot, _tmpBzl)

	// Backup the workspace file
	workspaceFile, err := findWorkspaceFile(repoRoot)
	if err != nil {
		return err
	}
	wsBackupFile, err := backUpWorkspaceFile(ctx, workspaceFile)
	if err != nil {
		return err
	}
	defer restoreWorkspaceFile(ctx, workspaceFile, wsBackupFile)
	// The update-repos to the tmp.bzl will not work (i.e., the file will be created but will not
	// have go_repository entries), if the gazelle:repository_macro directive is not removed.
	if err := removeDirectivesFromWorkspace(workspaceFile); err != nil {
		return err
	}

	// Update the repos
	args := []string{
		"run", gazelleBinTarget, "--", "update-repos",
		fmt.Sprintf("-from_file=%s", fromFile),
		fmt.Sprintf("-to_macro=%s%%%s", _tmpBzl, macroName),
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
	defer os.Remove(tmpBzlPath)

	// parse the resulting tmp.bzl for deps.bzl and WORKSPACE updates
	maybeRules, err := readFromTmp(tmpBzlPath, macroName)
	if err != nil {
		return err
	}

	// update deps
	if err := updateDepsBzlWithRules(depsPath, macroName, maybeRules); err != nil {
		return err
	}

	return nil
}

func readFromTmp(tmpBzlPath string, macroName string) ([]*rule.Rule, error) {
	var rules []*rule.Rule
	tmpBzl, err := rule.LoadMacroFile(tmpBzlPath, "tmp" /* pkg */, macroName /* DefName */)
	if err != nil {
		return nil, err
	}
	for _, r := range tmpBzl.Rules {
		maybeRule := rule.NewRule(maybeRuleKind, r.Name())
		maybeRule.AddArg(&bzl.Ident{
			Name: r.Kind(),
		})
		for _, k := range r.AttrKeys() {
			maybeRule.SetAttr(k, r.Attr(k))
		}
		// This is a weird special case.
		if r.Name() == "com_github_bazelbuild_buildtools" {
			maybeRule.SetAttr("build_naming_convention", "go_default_library")
		}
		rules = append(rules, maybeRule)
	}
	return rules, nil
}

func updateDepsBzlWithRules(depsPath, macroName string, maybeRules []*rule.Rule) error {
	depsBzl, err := rule.LoadMacroFile(depsPath, "deps" /* pkg */, macroName /* DefName */)
	if err != nil {
		return err
	}

	for _, r := range depsBzl.Rules {
		if r.Kind() == "go_repository" {
			r.Delete()
		}
		if r.Kind() == maybeRuleKind && len(r.Args()) == 1 {
			// We can't actually delete all maybe's because http_archive uses it too in here!
			if ident, ok := r.Args()[0].(*bzl.Ident); ok && ident.Name == "go_repository" {
				r.Delete()
			}
		}
	}

	for _, r := range maybeRules {
		r.Insert(depsBzl)
	}

	// Add the load statement
	maybeLoad := rule.NewLoad("@bazel_tools//tools/build_defs/repo:utils.bzl")
	maybeLoad.Add("maybe")
	maybeLoad.Insert(depsBzl, 0)

	return depsBzl.Save(depsPath)
}

// func readFromTmp(tmpBzlPath string) ([]*rule.Rule, []byte, error) {
// 	workspaceDirectivesBuff := new(bytes.Buffer)
// 	var rules []*rule.Rule
// 	tmpBzl, err := rule.LoadMacroFile(tmpBzlPath, "tmp" /* pkg */, macroName /* DefName */)
// 	if err != nil {
// 		return nil, nil, err
// 	}
// 	for _, r := range tmpBzl.Rules {
// 		maybeRule := rule.NewRule(maybeRuleKind, r.Name())
// 		maybeRule.AddArg(&bzl.Ident{
// 			Name: r.Kind(),
// 		})
// 		for _, k := range r.AttrKeys() {
// 			maybeRule.SetAttr(k, r.Attr(k))
// 		}
// 		var suffix string
// 		if r.Name() == "com_github_bazelbuild_buildtools" {
// 			maybeRule.SetAttr("build_naming_convention", "go_default_library")
// 			suffix = " build_naming_convention=go_default_library"
// 		}
// 		rules = append(rules, maybeRule)
// 		// TODO(chuck): Do I need to do this directive stuff as I only have one today. This code
// 		// will add one for each dep.
// 		fmt.Fprintf(workspaceDirectivesBuff, "# gazelle:repository go_repository name=%s importpath=%s%s\n",
// 			r.Name(),
// 			r.AttrString("importpath"),
// 			suffix,
// 		)
// 	}
// 	return rules, workspaceDirectivesBuff.Bytes(), nil
// }
