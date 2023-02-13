package main

import (
	"sort"

	"github.com/bazelbuild/bazel-gazelle/rule"
	bzl "github.com/bazelbuild/buildtools/build"
	"golang.org/x/exp/slices"
)

const goRepoRuleKind = "go_repository"
const bazelToolsUtilsLoadName = "@bazel_tools//tools/build_defs/repo:utils.bzl"
const maybeSymbol = "maybe"

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

	// Collect the existing loads in a map and remove them from the file.
	newLoadsMap := make(map[string]*rule.Load)
	for _, load := range depsBzl.Loads {
		nl := rule.NewLoad(load.Name())
		for _, s := range load.Symbols() {
			nl.Add(s)
		}
		newLoadsMap[load.Name()] = nl
		load.Delete()
	}

	// Add the load statement for maybe
	if l, ok := newLoadsMap[bazelToolsUtilsLoadName]; ok {
		if !slices.Contains(l.Symbols(), maybeSymbol) {
			l.Add(maybeSymbol)
		}
	} else {
		nl := rule.NewLoad(bazelToolsUtilsLoadName)
		nl.Add(maybeSymbol)
		newLoadsMap[bazelToolsUtilsLoadName] = nl
	}

	// Sort the loads and add them to the file
	newLoadNames := make([]string, 0, len(newLoadsMap))
	for name := range newLoadsMap {
		newLoadNames = append(newLoadNames, name)
	}
	sort.Strings(newLoadNames)
	for _, lname := range newLoadNames {
		if l, ok := newLoadsMap[lname]; ok {
			l.Insert(depsBzl, 1)
		}
	}

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
