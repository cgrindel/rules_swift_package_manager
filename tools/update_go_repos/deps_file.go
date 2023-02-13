package main

import (
	"github.com/bazelbuild/bazel-gazelle/rule"
	bzl "github.com/bazelbuild/buildtools/build"
)

const goRepoRuleKind = "go_repository"

func removeGoDeclarations(depsPath, macroName string) error {
	depsBzl, err := rule.LoadMacroFile(depsPath, "deps" /* pkg */, macroName /* DefName */)
	if err != nil {
		return err
	}
	for _, r := range depsBzl.Rules {
		if r.Kind() == goRepoRuleKind {
			r.Delete()
			continue
		}
		if r.Kind() == maybeRuleKind && len(r.Args()) == 1 {
			// Be sure that the maybe is a Go repo
			if ident, ok := r.Args()[0].(*bzl.Ident); ok && ident.Name == goRepoRuleKind {
				r.Delete()
				continue
			}
		}
	}
	return depsBzl.Save(depsPath)
}

func updateDepsBzlWithRules(depsPath, macroName string) error {
	depsBzl, err := rule.LoadMacroFile(depsPath, "deps" /* pkg */, macroName /* DefName */)
	if err != nil {
		return err
	}
	maybeRules := make([]*rule.Rule, 0, len(depsBzl.Rules))
	for _, r := range depsBzl.Rules {
		if r.Kind() == "go_repository" {
			mr := createMaybeRule(r)
			maybeRules = append(maybeRules, mr)
			r.Delete()
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

func createMaybeRule(r *rule.Rule) *rule.Rule {
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
	return maybeRule
}
